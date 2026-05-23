import AppKit

class OverlayView: NSView {
    private let container   = NSView()
    private let square      = NSView()
    private let squareSize: CGFloat = 200

    private let topTextLayer    = CATextLayer()
    private let bottomTextLayer = CATextLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        container.wantsLayer = true
        container.layer?.shadowColor   = NSColor.white.withAlphaComponent(0.75).cgColor
        container.layer?.shadowRadius  = 28
        container.layer?.shadowOpacity = 1.0
        container.layer?.shadowOffset  = .zero
        container.isHidden = true
        addSubview(container)

        square.wantsLayer = true
        square.layer?.cornerRadius  = 20
        square.layer?.cornerCurve   = .continuous
        square.layer?.masksToBounds = true
        square.layer?.borderColor   = NSColor.white.withAlphaComponent(0.65).cgColor
        square.layer?.borderWidth   = 1.0
        container.addSubview(square)

        let size = CGSize(width: squareSize, height: squareSize)
        square.frame    = CGRect(origin: .zero, size: size)
        container.frame = CGRect(
            x: (frame.width  - squareSize) / 2,
            y: (frame.height - squareSize) / 2,
            width: squareSize, height: squareSize
        )

        let fill = CALayer()
        fill.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
        fill.frame = CGRect(origin: .zero, size: size)
        square.layer?.addSublayer(fill)

        let highlight = CAGradientLayer()
        highlight.colors = [
            NSColor.white.withAlphaComponent(0.45).cgColor,
            NSColor.white.withAlphaComponent(0.08).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlight.locations  = [0.0, 0.45, 0.80]
        highlight.startPoint = CGPoint(x: 0.0, y: 1.0)
        highlight.endPoint   = CGPoint(x: 1.0, y: 0.0)
        highlight.frame = CGRect(origin: .zero, size: size)
        square.layer?.addSublayer(highlight)

        // Phrase text layers — square's CALayer has y=0 at bottom (non-flipped NSView)
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
            // Disable implicit animations so phrases appear/disappear instantly
            layer.actions = ["contents": NSNull()]
            square.layer?.addSublayer(layer)
        }

        // Top phrase: frame top = y+height = 175 → 25px from the top edge of the 200px square.
        // CATextLayer renders from the frame's top downward, so text starts 25px from the top.
        topTextLayer.frame    = CGRect(x: 12, y: 120, width: 176, height: 55)

        // Bottom phrase: frame top (maxY) ≈ 42px from bottom → single-line text (~16px)
        // ends at ≈26px from the bottom edge, matching the top phrase's ~25px top padding.
        bottomTextLayer.frame    = CGRect(x: 12, y: 20, width: 176, height: 22)
        bottomTextLayer.isWrapped = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func showSquare(at point: CGPoint) {
        let half = squareSize / 2
        let x = max(half, min(bounds.width  - half, point.x))
        let y = max(half, min(bounds.height - half, point.y))
        container.isHidden = false
        container.frame = CGRect(x: x - half, y: y - half, width: squareSize, height: squareSize)
    }

    func hideSquare() {
        container.isHidden = true
    }

    func updatePhrases(top: String, bottom: String) {
        topTextLayer.string    = top
        bottomTextLayer.string = bottom
    }
}
