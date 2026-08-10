import AppKit

/// The status bar glyph itself. A plain `NSStatusItem.button.image` can't
/// do a continuous spinner or a color morph, so this drives a couple of
/// `CAShapeLayer`s directly — a filled dot for settled states, plus a
/// rotating arc layered on top while checks are running.
final class BeaconIndicatorView: NSView {
    private let dotLayer = CAShapeLayer()
    private let spinnerLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setUpLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setUpLayers()
    }

    private func setUpLayers() {
        let dotRect = bounds.insetBy(dx: 3, dy: 3)
        dotLayer.path = CGPath(ellipseIn: dotRect, transform: nil)
        dotLayer.fillColor = NSColor.tertiaryLabelColor.cgColor
        layer?.addSublayer(dotLayer)

        spinnerLayer.path = CGPath(ellipseIn: dotRect.insetBy(dx: -2, dy: -2), transform: nil)
        spinnerLayer.fillColor = NSColor.clear.cgColor
        spinnerLayer.strokeColor = NSColor.systemYellow.cgColor
        spinnerLayer.lineWidth = 1.5
        spinnerLayer.strokeStart = 0
        spinnerLayer.strokeEnd = 0.75
        spinnerLayer.isHidden = true
        layer?.addSublayer(spinnerLayer)
    }

    func update(status: PullRequestStatus?) {
        spinnerLayer.removeAnimation(forKey: "spin")

        guard let status else {
            dotLayer.fillColor = NSColor.tertiaryLabelColor.cgColor
            spinnerLayer.isHidden = true
            return
        }

        switch status {
        case .checksRunning:
            spinnerLayer.isHidden = false
            dotLayer.fillColor = NSColor.clear.cgColor
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 0.9
            spin.repeatCount = .infinity
            spinnerLayer.add(spin, forKey: "spin")
        case .merged:
            spinnerLayer.isHidden = true
            dotLayer.fillColor = NSColor.systemPurple.cgColor
        case .checksPassed:
            spinnerLayer.isHidden = true
            dotLayer.fillColor = NSColor.systemGreen.cgColor
        case .reviewRequested:
            spinnerLayer.isHidden = true
            dotLayer.fillColor = NSColor.systemBlue.cgColor
        case .changesRequested:
            spinnerLayer.isHidden = true
            dotLayer.fillColor = NSColor.systemOrange.cgColor
        case .checksFailed:
            spinnerLayer.isHidden = true
            dotLayer.fillColor = NSColor.systemRed.cgColor
        }
    }
}
