import Cocoa

protocol HotkeyDelegate: AnyObject {
    func onHotkeyPress()
    func onHotkeyRelease()
}

class HotkeyManager {
    weak var delegate: HotkeyDelegate?
    private let logger: LoggerService
    private let settings = AppSettings.shared

    private var modifierPressedState: Bool = false
    private(set) var isTriggerPressed: Bool = false

    init(logger: LoggerService) {
        self.logger = logger
    }

    func setup() {
        requestAccessibility()
        logger.info("Setting up Hotkey monitors for trigger keyCode: \(settings.triggerKeyCode)")

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, isDown: true)
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyEvent(event, isDown: false)
        }
    }

    private func isModifierKey(_ keyCode: Int) -> Bool {
        [63, 54, 55, 56, 60, 58, 61, 59, 62].contains(keyCode)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let trigger = settings.triggerKeyCode
        guard isModifierKey(trigger), Int(event.keyCode) == trigger else { return }

        let isPressed: Bool
        switch trigger {
        case 63: isPressed = event.modifierFlags.contains(.function)
        case 54, 55: isPressed = event.modifierFlags.contains(.command)
        case 56, 60: isPressed = event.modifierFlags.contains(.shift)
        case 58, 61: isPressed = event.modifierFlags.contains(.option)
        case 59, 62: isPressed = event.modifierFlags.contains(.control)
        default: return
        }

        guard isPressed != modifierPressedState else { return }
        modifierPressedState = isPressed
        isTriggerPressed = isPressed

        logger.info("Hotkey [FlagsChanged] - isPressed: \(isPressed)")
        if isPressed {
            delegate?.onHotkeyPress()
        } else {
            delegate?.onHotkeyRelease()
        }
    }

    private func handleKeyEvent(_ event: NSEvent, isDown: Bool) {
        let trigger = settings.triggerKeyCode

        // Modifier triggers are handled exclusively by flagsChanged to prevent duplicates.
        guard !isModifierKey(trigger), Int(event.keyCode) == trigger else { return }

        if isDown {
            isTriggerPressed = true
            logger.info("Hotkey [KeyDown] trigger detected")
            delegate?.onHotkeyPress()
        } else {
            isTriggerPressed = false
            logger.info("Hotkey [KeyUp] trigger detected")
            delegate?.onHotkeyRelease()
        }
    }

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            logger.warning("Accessibility permissions required. Please enable in System Settings -> Privacy & Security -> Accessibility.")
        } else {
            logger.success("Accessibility permissions granted.")
        }
    }
}
