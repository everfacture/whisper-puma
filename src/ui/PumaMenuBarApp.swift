import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var isRecording = false
    
    var targetApp: NSRunningApplication?
    
    // Core Services via DI
    let logger = LoggerService.shared
    let backendManager: BackendProcessManager
    let audioService: AudioRecordingService
    let hotkeyManager: HotkeyManager
    let hudManager: HUDManager
    let pasteService: PasteService
    let networkService: NetworkService
    
    override init() {
        // Initialize services
        self.backendManager = BackendProcessManager(logger: logger)
        self.audioService = AudioRecordingService(logger: logger)
        self.hotkeyManager = HotkeyManager(logger: logger)
        self.hudManager = HUDManager()
        self.pasteService = PasteService(logger: logger)
        self.networkService = NetworkService(logger: logger)
        
        super.init()
        
        // Wire up delegates
        self.hotkeyManager.delegate = self
        self.audioService.delegate = self
        self.networkService.delegate = self
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        hotkeyManager.setup()
        backendManager.start()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        backendManager.stop()
    }
    
    private func setupMenuBar() {
        if let button = statusItem.button {
            button.title = "🐆"
            NSApp.setActivationPolicy(.accessory)
        }
        
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings (Coming Soon)", action: nil, keyEquivalent: "")
        settingsItem.isEnabled = false
        menu.addItem(settingsItem)
        
        let historyItem = NSMenuItem(title: "View History", action: #selector(viewHistory), keyEquivalent: "")
        menu.addItem(historyItem)
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Whisper Puma", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    @objc private func viewHistory() {
        let historyURL = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_history.log"))
        NSWorkspace.shared.open(historyURL)
    }
    
    private func playSound(name: String, volume: Float = 0.3) {
        if let sound = NSSound(named: name) {
            sound.volume = volume
            sound.play()
        }
    }
}

// MARK: - HotkeyDelegate
extension AppDelegate: HotkeyDelegate {
    func onHotkeyPress() {
        if !isRecording {
            isRecording = true
            
            // Capture the active app BEFORE we show the HUD and steal focus
            targetApp = NSWorkspace.shared.frontmostApplication
            
            playSound(name: "Submarine", volume: 0.2)
            hudManager.showHUD()
            
            DispatchQueue.main.async {
                self.statusItem.button?.title = "🔴"
            }
            audioService.startRecording()
        }
    }
    
    func onHotkeyRelease() {
        if isRecording {
            isRecording = false
            playSound(name: "Pop", volume: 0.2)
            hudManager.hideHUD()
            
            DispatchQueue.main.async {
                self.statusItem.button?.title = "⏳"
            }
            audioService.stopRecording()
        }
    }
}

// MARK: - AudioRecordingDelegate
extension AppDelegate: AudioRecordingDelegate {
    func onRecordingStarted() {
        // Handled via hotkey press
    }
    
    func onRecordingStopped(fileURL: URL) {
        networkService.sendForTranscription(fileURL: fileURL, targetApp: targetApp)
    }
}

// MARK: - NetworkDelegate
extension AppDelegate: NetworkDelegate {
    func onTranscriptionSuccess(text: String, targetApp: NSRunningApplication?) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = "🐆"
            self?.pasteService.processAndPaste(text, targetApp: targetApp)
            self?.targetApp = nil
        }
    }
    
    func onTranscriptionError(error: Error, targetApp: NSRunningApplication?) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = "🐆"
            self?.targetApp = nil
        }
    }
}

@main
struct WhisperPumaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
