import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var isRecording = false

    var targetApp: NSRunningApplication?
    var settingsWindow: SettingsWindowController?
    var historyWindow: HistoryWindowController?
    let settings = AppSettings.shared
    private var stopPressedAt: Date?
    private var recordingStartedAt: Date?
    private var shouldDiscardCurrentSession = false
    private var lastSessionStopAt: Date?
    private var pendingHoldStartWorkItem: DispatchWorkItem?
    private var lastDoubleTapPressAt: Date?
    private let fnHoldActivationDelay: TimeInterval = 0.14
    private let doubleTapThreshold: TimeInterval = 0.35

    // Core Services via DI
    let logger = LoggerService.shared
    let backendManager: BackendProcessManager
    let audioService: AudioRecordingService
    let hotkeyManager: HotkeyManager
    let hudManager: HUDManager
    let pasteService: PasteService
    let networkService: NetworkService

    override init() {
        self.backendManager = BackendProcessManager(logger: logger)
        self.audioService = AudioRecordingService(logger: logger)
        self.hotkeyManager = HotkeyManager(logger: logger)
        self.hudManager = HUDManager()
        self.pasteService = PasteService(logger: logger)
        self.networkService = NetworkService(logger: logger)

        super.init()

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
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "View History", action: #selector(viewHistory), keyEquivalent: "")
        menu.addItem(historyItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Whisper Puma", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc private func viewHistory() {
        if historyWindow == nil {
            historyWindow = HistoryWindowController()
        }
        historyWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func playSound(name: String, volume: Float = 0.2) {
        if let sound = NSSound(named: name) {
            sound.volume = volume
            sound.play()
        }
    }
}

// MARK: - HotkeyDelegate
extension AppDelegate: HotkeyDelegate {
    func onHotkeyPress() {
        let effectiveMode: RecordingMode = (settings.triggerKeyCode == AppSettings.fnKeyCode) ? .hold : settings.recordingMode
        logger.info("onHotkeyPress triggered in AppDelegate (isRecording: \(isRecording), mode: \(effectiveMode.rawValue))")
        switch effectiveMode {
        case .hold:
            handleHoldPress()
        case .toggle:
            if isRecording {
                stopRecordingSession()
            } else {
                startRecordingSession()
            }
        case .doubleTap:
            handleDoubleTapPress()
        }
    }

    func onHotkeyRelease() {
        let effectiveMode: RecordingMode = (settings.triggerKeyCode == AppSettings.fnKeyCode) ? .hold : settings.recordingMode
        if effectiveMode == .hold {
            pendingHoldStartWorkItem?.cancel()
            pendingHoldStartWorkItem = nil
            logger.info("onHotkeyRelease triggered (stopping recording)")
            stopRecordingSession()
        }
    }

    private func handleHoldPress() {
        guard !isRecording else { return }

        // Fn must be hold-only; require a short hold so accidental taps do not create empty sessions.
        if settings.triggerKeyCode == AppSettings.fnKeyCode {
            pendingHoldStartWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard !self.isRecording, self.hotkeyManager.isTriggerPressed else { return }
                self.startRecordingSession()
            }
            pendingHoldStartWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + fnHoldActivationDelay, execute: work)
            return
        }

        startRecordingSession()
    }

    private func handleDoubleTapPress() {
        let now = Date()

        if isRecording {
            if let previous = lastDoubleTapPressAt, now.timeIntervalSince(previous) <= doubleTapThreshold {
                stopRecordingSession()
                lastDoubleTapPressAt = nil
            } else {
                lastDoubleTapPressAt = now
                logger.info("Double-tap stop armed: tap again quickly to stop.")
            }
            return
        }

        startRecordingSession()
        lastDoubleTapPressAt = now
    }

    private func startRecordingSession() {
        guard !isRecording else { return }
        pendingHoldStartWorkItem?.cancel()
        pendingHoldStartWorkItem = nil
        if let lastStop = lastSessionStopAt, Date().timeIntervalSince(lastStop) < 0.25 {
            logger.info("Ignoring hotkey bounce: start throttled.")
            return
        }
        isRecording = true
        shouldDiscardCurrentSession = false
        recordingStartedAt = Date()

        targetApp = NSWorkspace.shared.frontmostApplication

        playSound(name: "Submarine")
        hudManager.showHUD()

        DispatchQueue.main.async {
            self.statusItem.button?.title = "🔴"
        }
        audioService.startRecording()
    }

    private func stopRecordingSession() {
        guard isRecording else { return }
        pendingHoldStartWorkItem?.cancel()
        pendingHoldStartWorkItem = nil
        isRecording = false

        let duration = Date().timeIntervalSince(recordingStartedAt ?? Date())
        if duration < 0.12 {
            shouldDiscardCurrentSession = true
            logger.info("Discarding ultra-short recording session (\(String(format: "%.3f", duration))s).")
        }

        stopPressedAt = Date()
        lastSessionStopAt = Date()

        playSound(name: "Pop")
        hudManager.hideHUD()

        DispatchQueue.main.async {
            self.statusItem.button?.title = "⏳"
        }
        audioService.stopRecording()
    }
}

// MARK: - AudioRecordingDelegate
extension AppDelegate: AudioRecordingDelegate {
    func onRecordingStarted(sampleRate: Double) {
        networkService.startStreamingSession(
            sampleRate: sampleRate,
            language: settings.languageCode,
            model: settings.modelVariant,
            targetApp: targetApp
        )
    }

    func onAudioChunk(data: Data, sampleRate: Double, t0Ms: Int64, t1Ms: Int64) {
        networkService.sendAudioChunk(data, t0Ms: t0Ms, t1Ms: t1Ms)
    }

    func onRecordingStopped() {
        if shouldDiscardCurrentSession {
            networkService.cancelStreamingSession()
            shouldDiscardCurrentSession = false
            targetApp = nil
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.button?.title = "🐆"
            }
            return
        }
        networkService.stopStreamingSession()
    }
}

// MARK: - NetworkDelegate
extension AppDelegate: NetworkDelegate {
    func onTranscriptionPartial(text: String) {
        if settings.latencyOverlayEnabled {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.button?.title = "…"
            }
        }
    }

    func onTranscriptionSuccess(text: String, targetApp: NSRunningApplication?, latencyMs: Double?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusItem.button?.title = "🐆"
            self.pasteService.processAndPaste(text, targetApp: targetApp) { insertedText in
                self.targetApp = nil

                if let stopPressedAt = self.stopPressedAt {
                    let totalMs = Date().timeIntervalSince(stopPressedAt) * 1000.0
                    LatencyMetrics.shared.addSample(ms: totalMs)
                }

                if let latencyMs = latencyMs {
                    self.logger.info("Backend stream latency: \(Int(latencyMs))ms")
                }

                self.logger.info("Inserted transcript (\(insertedText.count) chars).")
            }
        }
    }

    func onTranscriptionError(error: Error, targetApp: NSRunningApplication?) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = "🐆"
            self?.targetApp = nil
        }
        logger.error("Transcription error: \(error.localizedDescription)")
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
