import Cocoa

protocol HotkeyDelegate: AnyObject {
    func onHotkeyPress()
    func onHotkeyRelease()
}

class HotkeyManager {
    weak var delegate: HotkeyDelegate?
    private let logger: LoggerService
    private let settings = AppSettings.shared
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func setup() {
        requestAccessibility()
        logger.info("Setting up Hotkey monitors for trigger keyCode: \(settings.triggerKeyCode)")
        
        // Listen for modifier keys (Fn, Cmd, Alt, Shift)
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleEvent(event)
        }
        
        // Listen for standard keys
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleEvent(event)
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        let currentTrigger = settings.triggerKeyCode
        
        // Log all monitored events if they match modifier keys or trigger key for debugging
        if Int(event.keyCode) == currentTrigger || event.type == .flagsChanged {
            // logger.info("Event detected - Type: \(event.type), KeyCode: \(event.keyCode), SettingsTrigger: \(currentTrigger)")
        }
        
        guard Int(event.keyCode) == currentTrigger else { return }


        if event.type == .flagsChanged {
            // Surgical check for modifier keys
            let isPressed: Bool
            switch currentTrigger {
            case 63: isPressed = event.modifierFlags.contains(.function)
            case 54, 55: isPressed = event.modifierFlags.contains(.command)
            case 56, 60: isPressed = event.modifierFlags.contains(.shift)
            case 58, 61: isPressed = event.modifierFlags.contains(.option)
            case 59, 62: isPressed = event.modifierFlags.contains(.control)
            default: return 
            }

            logger.info("Hotkey [FlagsChanged] - isPressed: \(isPressed)")
            
            if isPressed {
                delegate?.onHotkeyPress()
            } else {
                delegate?.onHotkeyRelease()
            }
        } else if event.type == .keyDown {
            logger.info("Hotkey [KeyDown] trigger detected")
            delegate?.onHotkeyPress()
        } else if event.type == .keyUp {
            logger.info("Hotkey [KeyUp] trigger detected")
            delegate?.onHotkeyRelease()
        }
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
}
