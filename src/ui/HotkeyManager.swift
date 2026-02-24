import Cocoa

protocol HotkeyDelegate: AnyObject {
    func onHotkeyPress()
    func onHotkeyRelease()
}

class HotkeyManager {
    weak var delegate: HotkeyDelegate?
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func setup() {
        requestAccessibility()
        listenForFnKey()
    }
    
    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            logger.warning("Accessibility permissions required. Please enable in System Settings -> Privacy & Security -> Accessibility.")
        } else {
            logger.success("Accessibility permissions granted.")
        }
    }
    
    private func listenForFnKey() {
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            // Keycode 63 is the standard 'fn' key on macOS keyboards
            if event.keyCode == 63 {
                if event.modifierFlags.contains(.function) {
                    self?.delegate?.onHotkeyPress()
                } else {
                    self?.delegate?.onHotkeyRelease()
                }
            }
        }
    }
}
