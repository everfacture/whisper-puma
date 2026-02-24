import Foundation
import AVFoundation

protocol AudioRecordingDelegate: AnyObject {
    func onRecordingStarted()
    func onRecordingStopped(fileURL: URL)
}

class AudioRecordingService {
    private var audioEngine: AVAudioEngine!
    private var audioFile: AVAudioFile!
    private let logger: LoggerService
    private let tempFileURL = URL(fileURLWithPath: "/tmp/puma_dictation.wav")
    
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
        
        var settings = format.settings
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        
        do {
            audioFile = try AVAudioFile(forWriting: tempFileURL, settings: settings)
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                do {
                    try self?.audioFile.write(from: buffer)
                } catch {
                    self?.logger.error("Error writing audio")
                }
            }
            
            try audioEngine.start()
            logger.info("▶️ Recording started...")
            delegate?.onRecordingStarted()
            
        } catch {
            logger.error("Error starting engine: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil
        
        logger.info("⏹️ Recording stopped. Temp file at \(tempFileURL.path)")
        delegate?.onRecordingStopped(fileURL: tempFileURL)
    }
}
