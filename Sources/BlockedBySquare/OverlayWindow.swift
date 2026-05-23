import AppKit

class OverlayWindow: NSWindow {
    private var content: OverlayView!

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // One below screenSaverWindow so NSVisualEffectView behindWindow blending
        // is allowed by the compositor (it is disabled above screenSaverWindow level).
        // The CGEvent tap blocks all input regardless of window level.
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true  // blocking is handled by the CGEvent tap globally
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        content = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        self.contentView = content
        self.setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func showSquare(at localPos: CGPoint) {
        content.showSquare(at: localPos)
    }

    func hideSquare() {
        content.hideSquare()
    }
}
