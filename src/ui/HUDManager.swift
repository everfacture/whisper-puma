import Cocoa

class HUDManager {
    private var hoverWindow: NSWindow?

    func showHUD() {
        DispatchQueue.main.async {
            self.createWindowIfNeeded()
            self.positionWindow()
            self.hoverWindow?.alphaValue = 1.0
            self.hoverWindow?.orderFront(nil)
        }
    }

    func hideHUD() {
        DispatchQueue.main.async {
            self.hoverWindow?.orderOut(nil)
        }
    }

    private func createWindowIfNeeded() {
        if hoverWindow != nil { return }

        let windowSize = NSSize(width: 18, height: 18)
        let windowRect = NSRect(origin: .zero, size: windowSize)

        let window = NSWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true

        let container = NSView(frame: windowRect)
        container.wantsLayer = true

        let dot = CALayer()
        dot.frame = CGRect(x: 4, y: 4, width: 10, height: 10)
        dot.backgroundColor = NSColor.systemTeal.cgColor
        dot.cornerRadius = 5
        container.layer?.addSublayer(dot)

        window.contentView = container
        hoverWindow = window
    }

    private func positionWindow() {
        if let screen = NSScreen.main {
            let x = screen.frame.midX - 9
            let y = screen.frame.minY + 20
            hoverWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
