import Foundation
import Cocoa

protocol NetworkDelegate: AnyObject {
    func onTranscriptionPartial(text: String)
    func onTranscriptionSuccess(text: String, targetApp: NSRunningApplication?, latencyMs: Double?)
    func onTranscriptionError(error: Error, targetApp: NSRunningApplication?)
}

class NetworkService {
    static let shared = NetworkService(logger: LoggerService.shared)

    weak var delegate: NetworkDelegate?
    private let logger: LoggerService

    private var webSocketTask: URLSessionWebSocketTask?
    private var webSocketSession: URLSession?
    private var sessionId: String?
    private var streamTargetApp: NSRunningApplication?
    private var isStreaming = false
    private var lastPartialText: String = ""

    init(logger: LoggerService) {
        self.logger = logger
    }

    func startStreamingSession(sampleRate: Double, language: String, model: String, targetApp: NSRunningApplication?) {
        guard !isStreaming else { return }
        guard let wsURL = URL(string: "ws://127.0.0.1:\(Constants.backendPort)/stream") else { return }

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 120

        webSocketSession = URLSession(configuration: cfg)
        webSocketTask = webSocketSession?.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        isStreaming = true
        streamTargetApp = targetApp
        sessionId = UUID().uuidString
        lastPartialText = ""

        listenForWebSocketMessages()

        let payload: [String: Any] = [
            "type": "session.start",
            "session_id": sessionId ?? "",
            "sample_rate": Int(sampleRate),
            "language": language,
            "model": model
        ]
        sendJSON(payload)
    }

    func sendAudioChunk(_ data: Data, t0Ms: Int64, t1Ms: Int64) {
        guard isStreaming, let sid = sessionId else { return }
        let payload: [String: Any] = [
            "type": "audio.chunk",
            "session_id": sid,
            "pcm16_base64": data.base64EncodedString(),
            "t0_ms": t0Ms,
            "t1_ms": t1Ms
        ]
        sendJSON(payload)
    }

    func stopStreamingSession() {
        guard isStreaming, let sid = sessionId else { return }
        sendJSON(["type": "session.stop", "session_id": sid])
    }

    func cancelStreamingSession() {
        isStreaming = false
        cleanupWebSocket()
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let wsTask = webSocketTask else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let text = String(data: data, encoding: .utf8) else { return }
            wsTask.send(.string(text)) { [weak self] error in
                if let error = error {
                    self?.logger.error("WS send failed: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("WS encode failed: \(error)")
        }
    }

    private func listenForWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.isStreaming = false
                self.delegate?.onTranscriptionError(error: error, targetApp: self.streamTargetApp)
                self.cleanupWebSocket()

            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWebSocketText(text)
                    }
                @unknown default:
                    break
                }

                if self.isStreaming {
                    self.listenForWebSocketMessages()
                }
            }
        }
    }

    private func handleWebSocketText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let type = json["type"] as? String ?? ""

            if type == "transcript.partial" {
                if let partial = json["text"] as? String, !partial.isEmpty {
                    lastPartialText = partial
                    delegate?.onTranscriptionPartial(text: partial)
                }
                return
            }

            if type == "transcript.final" {
                isStreaming = false
                let final = (json["text"] as? String) ?? ""
                let latencyMs = (json["latency_ms"] as? NSNumber)?.doubleValue

                let finalTrimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
                let partialTrimmed = lastPartialText.trimmingCharacters(in: .whitespacesAndNewlines)

                if finalTrimmed.isEmpty && !partialTrimmed.isEmpty {
                    delegate?.onTranscriptionSuccess(text: partialTrimmed, targetApp: streamTargetApp, latencyMs: latencyMs)
                } else if finalTrimmed.isEmpty {
                    delegate?.onTranscriptionError(
                        error: NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No speech detected or backend returned empty transcript."]),
                        targetApp: streamTargetApp
                    )
                } else {
                    delegate?.onTranscriptionSuccess(text: finalTrimmed, targetApp: streamTargetApp, latencyMs: latencyMs)
                }

                cleanupWebSocket()
                return
            }

            if type == "session.error" {
                isStreaming = false
                let message = (json["message"] as? String) ?? "Streaming error"
                delegate?.onTranscriptionError(
                    error: NSError(domain: "NetworkService", code: -2, userInfo: [NSLocalizedDescriptionKey: message]),
                    targetApp: streamTargetApp
                )
                cleanupWebSocket()
            }
        } catch {
            logger.error("WS parse failed: \(error)")
        }
    }

    private func cleanupWebSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        webSocketSession?.invalidateAndCancel()
        webSocketSession = nil
        sessionId = nil
        streamTargetApp = nil
        lastPartialText = ""
    }

    // Legacy fallback: keep existing HTTP endpoint behavior.
    func sendForTranscription(fileURL: URL, targetApp: NSRunningApplication?) {
        guard let url = URL(string: "http://127.0.0.1:\(Constants.backendPort)/transcribe") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["file": fileURL.path]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { [weak self] data, _, error in
            if let error = error {
                self?.logger.error("Error from backend: \(error.localizedDescription)")
                self?.delegate?.onTranscriptionError(error: error, targetApp: targetApp)
                return
            }

            guard let data = data else { return }
            self?.parseTranscriptionResponse(data: data, targetApp: targetApp)
        }
        task.resume()
    }

    func fetchAvailableModels(completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:\(Constants.backendPort)/models") else {
            completion([])
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [String] {
                    completion(models)
                } else {
                    completion([])
                }
            } catch {
                completion([])
            }
        }
        task.resume()
    }

    private func parseTranscriptionResponse(data: Data, targetApp: NSRunningApplication?) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let text = json["text"] as? String, !text.isEmpty {
                    delegate?.onTranscriptionSuccess(text: text, targetApp: targetApp, latencyMs: nil)
                } else {
                    logger.warning("Backend returned empty text.")
                    delegate?.onTranscriptionError(
                        error: NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No speech detected or backend failed."]),
                        targetApp: targetApp
                    )
                }
            }
        } catch {
            logger.error("Failed to parse backend response: \(error)")
            delegate?.onTranscriptionError(error: error, targetApp: targetApp)
        }
    }
}
