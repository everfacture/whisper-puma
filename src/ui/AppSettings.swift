import Foundation
import Cocoa

enum RecordingMode: String, Codable, CaseIterable {
    case hold = "Hold to Talk"
    case toggle = "Toggle (Click to Talk)"
    case doubleTap = "Double Tap"
}

enum InsertionMode: String, Codable, CaseIterable {
    case directThenClipboard = "Direct typing + fallback"
    case clipboardOnly = "Clipboard only"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let fnKeyCode = 63
    static let defaultModelRepo = "mlx-community/whisper-large-v3-mlx"

    @Published var triggerKeyCode: Int {
        didSet {
            if triggerKeyCode == AppSettings.fnKeyCode && recordingMode != .hold {
                recordingMode = .hold
            }
            UserDefaults.standard.set(triggerKeyCode, forKey: "triggerKeyCode")
        }
    }

    @Published var recordingMode: RecordingMode {
        didSet {
            if triggerKeyCode == AppSettings.fnKeyCode && recordingMode != .hold {
                recordingMode = .hold
                return
            }
            UserDefaults.standard.set(recordingMode.rawValue, forKey: "recordingMode")
        }
    }

    @Published var modelVariant: String {
        didSet {
            if modelVariant != AppSettings.defaultModelRepo {
                modelVariant = AppSettings.defaultModelRepo
                return
            }
            UserDefaults.standard.set(modelVariant, forKey: "modelVariant")
        }
    }

    @Published var insertionMode: InsertionMode {
        didSet { UserDefaults.standard.set(insertionMode.rawValue, forKey: "insertionMode") }
    }

    @Published var spokenCommandsEnabled: Bool {
        didSet { UserDefaults.standard.set(spokenCommandsEnabled, forKey: "spokenCommandsEnabled") }
    }

    @Published var asyncPolishEnabled: Bool {
        didSet { UserDefaults.standard.set(asyncPolishEnabled, forKey: "asyncPolishEnabled") }
    }

    @Published var latencyOverlayEnabled: Bool {
        didSet { UserDefaults.standard.set(latencyOverlayEnabled, forKey: "latencyOverlayEnabled") }
    }

    @Published var languageCode: String {
        didSet { UserDefaults.standard.set(languageCode, forKey: "languageCode") }
    }

    private init() {
        let trigger = UserDefaults.standard.object(forKey: "triggerKeyCode") as? Int ?? 63
        self.triggerKeyCode = trigger

        let savedMode = UserDefaults.standard.string(forKey: "recordingMode") ?? RecordingMode.hold.rawValue
        let loadedMode = RecordingMode(rawValue: savedMode) ?? .hold
        self.recordingMode = (trigger == AppSettings.fnKeyCode) ? .hold : loadedMode

        self.modelVariant = AppSettings.defaultModelRepo

        let savedInsertion = UserDefaults.standard.string(forKey: "insertionMode") ?? InsertionMode.directThenClipboard.rawValue
        self.insertionMode = InsertionMode(rawValue: savedInsertion) ?? .directThenClipboard

        self.spokenCommandsEnabled = UserDefaults.standard.object(forKey: "spokenCommandsEnabled") as? Bool ?? true
        self.asyncPolishEnabled = UserDefaults.standard.object(forKey: "asyncPolishEnabled") as? Bool ?? true
        self.latencyOverlayEnabled = UserDefaults.standard.object(forKey: "latencyOverlayEnabled") as? Bool ?? true
        self.languageCode = UserDefaults.standard.string(forKey: "languageCode") ?? "en"

        UserDefaults.standard.set(AppSettings.defaultModelRepo, forKey: "modelVariant")
    }
}
