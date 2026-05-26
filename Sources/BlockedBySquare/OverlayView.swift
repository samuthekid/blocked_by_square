import AppKit
import SwiftUI

class OverlayView: NSView {
  private let container = NSView()
  private var glassView: NSView!
  private let textView = NSView()
  private let squareSize: CGFloat = 200

  private let topTextLayer = CATextLayer()
  private let bottomTextLayer = CATextLayer()

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true

    container.wantsLayer = true
    container.isHidden = true
    addSubview(container)

    let size = CGSize(width: squareSize, height: squareSize)
    let squareRect = CGRect(origin: .zero, size: size)

    if #available(macOS 26.0, *) {
      let hosting = NSHostingView(rootView: GlassSquareView())
      hosting.frame = squareRect
      hosting.wantsLayer = true
      hosting.layer?.shadowColor = NSColor.white.withAlphaComponent(0.75).cgColor
      hosting.layer?.shadowRadius = 28
      hosting.layer?.shadowOpacity = 1.0
      hosting.layer?.shadowOffset = .zero
      glassView = hosting
    } else {
      let vfx = NSVisualEffectView(frame: squareRect)
      vfx.material = .hudWindow
      vfx.blendingMode = .behindWindow
      vfx.state = .active
      vfx.wantsLayer = true
      vfx.layer?.cornerRadius = 20
      vfx.layer?.cornerCurve = .continuous
      vfx.layer?.masksToBounds = true
      vfx.layer?.borderColor = NSColor.white.withAlphaComponent(0.40).cgColor
      vfx.layer?.borderWidth = 0.75
      vfx.layer?.shadowColor = NSColor.white.withAlphaComponent(0.75).cgColor
      vfx.layer?.shadowRadius = 28
      vfx.layer?.shadowOpacity = 1.0
      vfx.layer?.shadowOffset = .zero
      glassView = vfx
    }
    container.addSubview(glassView)

    // Text lives in its own view — opacity changes never touch it
    textView.wantsLayer = true
    textView.frame = squareRect
    container.addSubview(textView)

    container.frame = CGRect(
      x: (frame.width - squareSize) / 2,
      y: (frame.height - squareSize) / 2,
      width: squareSize, height: squareSize
    )

    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    let textFont = NSFont.systemFont(ofSize: 13, weight: .medium) as CTFont

    for layer in [topTextLayer, bottomTextLayer] {
      layer.font = textFont
      layer.fontSize = 13
      layer.foregroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
      layer.alignmentMode = .center
      layer.isWrapped = true
      layer.truncationMode = .end
      layer.contentsScale = scale
      layer.actions = ["contents": NSNull()]
      textView.layer?.addSublayer(layer)
    }

    bottomTextLayer.isWrapped = false
    let s = Settings.shared
    updatePadding(top: CGFloat(s.topPadding), bottom: CGFloat(s.bottomPadding))
  }

  required init?(coder: NSCoder) { fatalError() }

  func showSquare(at point: CGPoint) {
    let half = squareSize / 2
    let x = max(half, min(bounds.width - half, point.x))
    let y = max(half, min(bounds.height - half, point.y))
    container.isHidden = false
    container.frame = CGRect(x: x - half, y: y - half, width: squareSize, height: squareSize)
  }

  func hideSquare() {
    container.isHidden = true
  }

  func updatePhrases(top: String, bottom: String) {
    topTextLayer.string = top
    bottomTextLayer.string = bottom
  }

  private var topColorLight = NSColor.black
  private var topColorDark = NSColor.white
  private var bottomColorLight = NSColor.black
  private var bottomColorDark = NSColor.white

  func updateTextColors(
    topLight: NSColor, topDark: NSColor, bottomLight: NSColor, bottomDark: NSColor
  ) {
    topColorLight = topLight
    topColorDark = topDark
    bottomColorLight = bottomLight
    bottomColorDark = bottomDark
    applyTextColors()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    applyTextColors()
  }

  private func applyTextColors() {
    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    topTextLayer.foregroundColor = (isDark ? topColorDark : topColorLight).cgColor
    bottomTextLayer.foregroundColor = (isDark ? bottomColorDark : bottomColorLight).cgColor
  }

  func updatePadding(top: CGFloat, bottom: CGFloat) {
    let topHeight: CGFloat = 55
    let bottomHeight: CGFloat = 22
    let topMaxY = squareSize - top
    topTextLayer.frame = CGRect(
      x: 12, y: topMaxY - topHeight, width: squareSize - 24, height: topHeight)
    bottomTextLayer.frame = CGRect(x: 12, y: bottom, width: squareSize - 24, height: bottomHeight)
  }

}

@available(macOS 26.0, *)
private struct GlassSquareView: View {
  var body: some View {
    Rectangle()
      .fill(.clear)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}
