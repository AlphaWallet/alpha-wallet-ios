//
//  LoadingView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.03.2021.
//

import UIKit

class ActivityLoadingIndicatorView: UIView {

    var lineWidth: CGFloat = 2
    var lineColor: UIColor = .red {
        didSet {
            circleLayer.strokeColor = lineColor.cgColor
        }
    }
    var backgroundLineColor: UIColor = .lightGray {
        didSet {
            backgroundLayer.strokeColor = backgroundLineColor.cgColor
        }
    }

    var backgroundFillColor: UIColor = .white {
        didSet {
            backgroundLayer.fillColor = backgroundFillColor.cgColor
        }
    }

    var duration: Double = 1.5
    private var circleAnimation: Bool = false

    private lazy var circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = lineColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.anchorPoint = CGPoint(x: 1, y: 1)

        return layer
    }()

    private lazy var backgroundLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = backgroundLineColor.cgColor
        layer.lineWidth = lineWidth
        layer.fillColor = backgroundFillColor.cgColor

        return layer
    }()

    private var radius: CGFloat {
        if frame.width < frame.height {
            return (frame.width - lineWidth) / 2
        } else {
            return (frame.height - lineWidth) / 2
        }
    }

    private var pathCenter: CGPoint {
        return convert(center, from: superview)
    }

    init() {
        super.init(frame: .zero)

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(circleLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func startAnimating() {
        guard !circleAnimation else { return }
        circleAnimation = true
        runAnimation()
    }

    func stopAnimating() {
        guard circleAnimation else { return }
        circleAnimation = false

        layer.removeAllAnimations()
    }

    private func runAnimation() {
        CATransaction.animate(block: {
            let timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            circleLayer.add(CircularLoadingIndicatorView.Animation.createRotationAnimation(duration: duration, timingFunction: timingFunction), forKey: CircularLoadingIndicatorView.Animation.Key.circle)
        }, completion: { [weak self] in
            guard let strongSelf = self else { return }

            if strongSelf.circleAnimation {
                strongSelf.runAnimation()
            }
        })
    }

    private func draw(backgroundLayer layer: CAShapeLayer) {
        let path = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: 0, endAngle: 2*CGFloat.pi, clockwise: true)
        layer.lineWidth = lineWidth
        layer.lineCap = CAShapeLayerLineCap.square
        layer.path = path.cgPath
        layer.fillColor = backgroundFillColor.cgColor
        layer.strokeColor = backgroundLineColor.cgColor
    }

    private func draw(circleLayer layer: CAShapeLayer) {
        let center: CGFloat = frame.size.width

        let arcCenter = CGPoint(x: center, y: center)

        layer.path = UIBezierPath(arcCenter: arcCenter, radius: radius, startAngle: 0, endAngle: 0.8, clockwise: true).cgPath
        layer.lineWidth = lineWidth
        layer.lineCap = CAShapeLayerLineCap.square
        layer.bounds = bounds
        layer.position = CGPoint(x: self.layer.frame.width / 2.0, y: self.layer.frame.height / 2.0)
    }

    override func layoutSublayers(of layer: CALayer) {
        draw(backgroundLayer: backgroundLayer)
        draw(circleLayer: circleLayer)
    }
}
