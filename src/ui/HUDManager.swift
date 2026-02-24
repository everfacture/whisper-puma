import Cocoa
import QuartzCore

class HUDManager {
    private var hoverWindow: NSWindow?
    
    func showHUD() {
        DispatchQueue.main.async {
            self.createWindowIfNeeded()
            self.positionWindow()
            self.animateIn()
        }
    }
    
    func hideHUD() {
        DispatchQueue.main.async {
            self.animateOut()
        }
    }
    
    private func createWindowIfNeeded() {
        if hoverWindow != nil { return }
        
        let windowSize = NSSize(width: 24, height: 24)
        let windowRect = NSRect(origin: .zero, size: windowSize)
        
        let window = NSWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        
        let container = NSView(frame: windowRect)
        container.wantsLayer = true
        
        let circleLayer = CALayer()
        let inset: CGFloat = 6
        circleLayer.frame = CGRect(x: inset, y: inset, width: windowSize.width - 2*inset, height: windowSize.height - 2*inset)
        circleLayer.backgroundColor = NSColor.systemCyan.cgColor
        circleLayer.cornerRadius = (windowSize.width - 2*inset) / 2
        
        circleLayer.shadowColor = NSColor.systemCyan.cgColor
        circleLayer.shadowRadius = 8
        circleLayer.shadowOpacity = 0.9
        circleLayer.shadowOffset = .zero
        
        container.layer?.addSublayer(circleLayer)
        window.contentView = container
        hoverWindow = window
        
        addAnimations(to: circleLayer)
    }
    
    private func addAnimations(to layer: CALayer) {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.0
        pulse.fromValue = 1.0
        pulse.toValue = 1.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.duration = 1.0
        fade.fromValue = 1.0
        fade.toValue = 0.3
        fade.autoreverses = true
        fade.repeatCount = .infinity
        
        layer.add(pulse, forKey: "pulse")
        layer.add(fade, forKey: "fade")
    }
    
    private func positionWindow() {
        if let screen = NSScreen.main {
            let x = screen.frame.midX - 12
            let y = screen.frame.minY + 24
            hoverWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    private func animateIn() {
        hoverWindow?.alphaValue = 0
        hoverWindow?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            hoverWindow?.animator().alphaValue = 1.0
        })
    }
    
    private func animateOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            hoverWindow?.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.hoverWindow?.orderOut(nil)
        })
    }
}
