internal import AppKit
import SwiftUI

final class AudioSpectrumNSView: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var animationTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barCount = 4
        let barWidth: CGFloat = 2
        let spacing: CGFloat = 2
        let totalHeight: CGFloat = 12

        for i in 0..<barCount {
            let x = CGFloat(i) * (barWidth + spacing)
            let layer = CAShapeLayer()
            layer.frame = CGRect(x: x, y: 0, width: barWidth, height: totalHeight)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: x + barWidth / 2, y: totalHeight / 2)
            layer.fillColor = NSColor.white.cgColor
            layer.backgroundColor = NSColor.white.cgColor
            layer.masksToBounds = true
            let path = NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                xRadius: barWidth / 2, yRadius: barWidth / 2
            )
            layer.path = path.cgPath
            barLayers.append(layer)
            barScales.append(0.35)
            self.layer?.addSublayer(layer)
        }
    }

    func setPlaying(_ playing: Bool) {
        if playing {
            guard animationTimer == nil else { return }
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.updateBars()
            }
            updateBars()
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            resetBars()
        }
    }

    private func updateBars() {
        for (i, barLayer) in barLayers.enumerated() {
            let from = barScales[i]
            let to = CGFloat.random(in: 0.35...1.0)
            barScales[i] = to
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = from
            anim.toValue = to
            anim.duration = 0.3
            anim.autoreverses = true
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            if #available(macOS 13.0, *) {
                anim.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 24, preferred: 24)
            }
            barLayer.add(anim, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    let isPlaying: Bool

    func makeNSView(context: Context) -> AudioSpectrumNSView {
        let v = AudioSpectrumNSView()
        v.setPlaying(isPlaying)
        return v
    }

    func updateNSView(_ nsView: AudioSpectrumNSView, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}
