import Foundation
import Cocoa

protocol NetworkDelegate: AnyObject {
    func onTranscriptionSuccess(text: String, targetApp: NSRunningApplication?)
    func onTranscriptionError(error: Error, targetApp: NSRunningApplication?)
}

class NetworkService {
    weak var delegate: NetworkDelegate?
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func sendForTranscription(fileURL: URL, targetApp: NSRunningApplication?) {
        guard let url = URL(string: "http://127.0.0.1:8111/transcribe") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["file": fileURL.path]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        // Use a custom session with a 5-minute timeout to allow the initial 1.5GB model download
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
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
    
    private func parseTranscriptionResponse(data: Data, targetApp: NSRunningApplication?) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let text = json["text"] as? String, !text.isEmpty {
                    delegate?.onTranscriptionSuccess(text: text, targetApp: targetApp)
                } else {
                    // Empty text, meaning transcription failed or was totally silent
                    logger.warning("Backend returned empty text.")
                    delegate?.onTranscriptionError(error: NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No speech detected or backend failed."]), targetApp: targetApp)
                }
            }
        } catch {
            logger.error("Failed to parse backend response: \(error)")
            delegate?.onTranscriptionError(error: error, targetApp: targetApp)
        }
    }
}
