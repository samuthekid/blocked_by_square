import AppKit

class OverlayView: NSView {
    private let container = NSView()   // unclipped, carries the glow/shadow
    private let square    = NSView()   // clipped to rounded corners
    private let squareSize: CGFloat = 200

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

        // Semi-transparent white base — window is .clear so the desktop shows through
        let fill = CALayer()
        fill.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
        fill.frame = CGRect(origin: .zero, size: size)
        square.layer?.addSublayer(fill)

        // Specular highlight — simulates light hitting the glass surface
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
}
