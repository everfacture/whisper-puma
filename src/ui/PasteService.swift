import Cocoa

class PasteService {
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func processAndPaste(_ text: String, targetApp: NSRunningApplication?) {
        saveToHistory(text)
        copyToClipboard(text)
        simulatePasteKeystroke(text: text, targetApp: targetApp)
    }
    
    private func saveToHistory(_ text: String) {
        let historyURL = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_history.log"))
        guard let data = (text + "\n").data(using: .utf8) else { return }
        
        if FileManager.default.fileExists(atPath: historyURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: historyURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: historyURL)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func simulatePasteKeystroke(text: String, targetApp: NSRunningApplication?) {
        let appToFocus = targetApp ?? NSWorkspace.shared.frontmostApplication
        let appName = appToFocus?.localizedName ?? "System Events"
        
        // Ensure the target application is fully focused
        appToFocus?.activate()
        Thread.sleep(forTimeInterval: 0.1)

        // First attempt: Hardware-level CGEvent (often the fastest, but sandboxes might block it)
        let vKeyCode: CGKeyCode = 0x09
        let src = CGEventSource(stateID: .hidSystemState)
        
        if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
            
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            logger.info("Attempted CGEvent hardware paste targeting \(appName)")
        }
        
        // Wait a tiny bit, then forcefully try a secondary targeted AppleScript
        // This acts as a backup in case the application ignored the hardware-level fake keystroke
        Thread.sleep(forTimeInterval: 0.1)
        
        let scriptSource = """
        tell application "System Events"
            tell process "\(appName)"
                set frontmost to true
                keystroke "v" using command down
            end tell
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                logger.warning("AppleScript backup paste failed: \(error)")
            } else {
                logger.info("Executed AppleScript backup paste targeting \(appName).")
            }
        }
        
        logger.success("Completed paste simulation for '\(text)'!")
    }
}
