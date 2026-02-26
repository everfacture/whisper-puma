import Foundation
import AVFoundation

protocol AudioRecordingDelegate: AnyObject {
    func onRecordingStarted(sampleRate: Double)
    func onAudioChunk(data: Data, sampleRate: Double, t0Ms: Int64, t1Ms: Int64)
    func onRecordingStopped()
}

class AudioRecordingService {
    private var audioEngine: AVAudioEngine
    private let logger: LoggerService
    private var cumulativeSamples: Int64 = 0

    weak var delegate: AudioRecordingDelegate?

    init(logger: LoggerService) {
        self.logger = logger
        self.audioEngine = AVAudioEngine()
    }

    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            if granted {
                self?.logger.success("Microphone access granted.")
            } else {
                self?.logger.error("Microphone access denied.")
            }
        }
    }

    func startRecording() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        cumulativeSamples = 0
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let frameCount = Int64(buffer.frameLength)
            guard frameCount > 0 else { return }

            let t0 = Int64((Double(self.cumulativeSamples) / sampleRate) * 1000.0)
            self.cumulativeSamples += frameCount
            let t1 = Int64((Double(self.cumulativeSamples) / sampleRate) * 1000.0)

            if let pcmData = self.convertBufferToPCM16(buffer: buffer) {
                self.delegate?.onAudioChunk(data: pcmData, sampleRate: sampleRate, t0Ms: t0, t1Ms: t1)
            }
        }

        do {
            try audioEngine.start()
            logger.info("▶️ Recording started...")
            delegate?.onRecordingStarted(sampleRate: sampleRate)
        } catch {
            logger.error("Error starting engine: \(error)")
        }
    }

    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        logger.info("⏹️ Recording stopped.")
        delegate?.onRecordingStopped()
    }

    private func convertBufferToPCM16(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frameLength > 0 else { return nil }

        var output = Data(capacity: frameLength * MemoryLayout<Int16>.size)

        for frame in 0..<frameLength {
            var mixed: Float = 0
            for ch in 0..<channels {
                mixed += channelData[ch][frame]
            }
            mixed /= Float(max(channels, 1))
            let clamped = max(-1.0, min(1.0, mixed))
            var i16 = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: &i16) { output.append(contentsOf: $0) }
        }

        return output
    }
}
