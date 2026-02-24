import Foundation
import Cocoa

enum RecordingMode: String, Codable, CaseIterable {
    case hold = "Hold to Talk"
    case toggle = "Toggle (Click to Talk)"
    case doubleTap = "Double Tap"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var triggerKeyCode: Int {
        didSet { UserDefaults.standard.set(triggerKeyCode, forKey: "triggerKeyCode") }
    }
    
    @Published var recordingMode: RecordingMode {
        didSet { UserDefaults.standard.set(recordingMode.rawValue, forKey: "recordingMode") }
    }
    
    @Published var modelVariant: String {
        didSet { UserDefaults.standard.set(modelVariant, forKey: "modelVariant") }
    }
    
    private init() {
        // Defaults: 63 is 'fn' key
        self.triggerKeyCode = UserDefaults.standard.object(forKey: "triggerKeyCode") as? Int ?? 63
        
        let savedMode = UserDefaults.standard.string(forKey: "recordingMode") ?? RecordingMode.hold.rawValue
        self.recordingMode = RecordingMode(rawValue: savedMode) ?? .hold
        
        self.modelVariant = UserDefaults.standard.string(forKey: "modelVariant") ?? "distil-whisper-large-v3"

    }
}
