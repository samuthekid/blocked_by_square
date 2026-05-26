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

    self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = false
    self.ignoresMouseEvents = true
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

  func updatePhrases(top: String, bottom: String) {
    content.updatePhrases(top: top, bottom: bottom)
  }

  func updateTextColors(
    topLight: NSColor, topDark: NSColor, bottomLight: NSColor, bottomDark: NSColor
  ) {
    content.updateTextColors(
      topLight: topLight, topDark: topDark,
      bottomLight: bottomLight, bottomDark: bottomDark)
  }

  func updatePadding(top: CGFloat, bottom: CGFloat) {
    content.updatePadding(top: top, bottom: bottom)
  }
}
