//
//  ActivityIndicatorView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

class ActivityIndicatorControl: UIControl {
    private let circularLoadingView: CircularLoadingIndicatorView = {
        let control = CircularLoadingIndicatorView()
        control.lineColor = R.color.green()!
        control.backgroundLineColor = Colors.loadingIndicatorBorder
        control.checkmarkColor = R.color.green()!
        control.translatesAutoresizingMaskIntoConstraints = false
        control.duration = 1.5

        return control
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(circularLoadingView)
        NSLayoutConstraint.activate([
            circularLoadingView.anchorsConstraint(to: self),

            widthAnchor.constraint(equalToConstant: 50),
            heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func startAnimating() {
        circularLoadingView.startAnimating()
    }

    func stopAnimating(animated: Bool = true, completion: (() -> Void)? = nil) {
        circularLoadingView.stopAnimating(completion: completion)
    }
}

class CircularLoadingIndicatorView: UIView {

    var lineWidth: CGFloat = 2
    var circleWidth: CGFloat = 15
    var lineColor: UIColor = .red {
        didSet {
            fillLayer.strokeColor = lineColor.cgColor
            circleLayer.fillColor = lineColor.cgColor
        }
    }
    var backgroundLineColor: UIColor = .lightGray {
        didSet {
            backgroundLayer.strokeColor = backgroundLineColor.cgColor
        }
    }
    var checkmarkColor: UIColor = .red {
        didSet {
            checkmarkLayer.strokeColor = checkmarkColor.cgColor
        }
    }

    var duration: Double = 2.0
    var checkmarkWidth: CGFloat = 4

    private var checkmarkAnimation: Bool = false
    private var circleAnimation: Bool = false
    private var completion: (() -> Void)?

    private lazy var circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = lineColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.anchorPoint = CGPoint(x: 1, y: 1)

        return layer
    }()

    private lazy var fillLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineCap = CAShapeLayerLineCap.round
        layer.lineWidth = lineWidth
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = lineColor.cgColor
        layer.strokeEnd = 0

        return layer
    }()

    private lazy var backgroundLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = backgroundLineColor.cgColor
        layer.lineWidth = lineWidth
        layer.fillColor = UIColor.clear.cgColor

        return layer
    }()

    private lazy var checkmarkLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = checkmarkWidth
        layer.strokeEnd = 0
        layer.strokeColor = checkmarkColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.lineJoin = CAShapeLayerLineJoin.round

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
        layer.addSublayer(fillLayer)
        layer.addSublayer(circleLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func startAnimating() {
        guard !circleAnimation && !checkmarkAnimation else { return }
        circleAnimation = true
        resetAnimation()
        runAnimation()
    }

    func stopAnimating(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard circleAnimation else {
            //NOTE: for some reasons operation can be performed very fast and in case when completion for `.pending` won't be called `circleAnimation` will be false, in this case we need call completion closure
            completion?()
            return
        }
        self.completion = completion
        circleAnimation = false
        checkmarkAnimation = true
        completion?()
        self.completion = nil
        layer.removeAllAnimations()
    }

    private func resetAnimation() {
        checkmarkAnimation = false
        circleLayer.opacity = 1
        checkmarkLayer.removeFromSuperlayer()
    }

    private func runAnimation() {
        CATransaction.animate(block: {
            fillLayer.strokeEnd = CGFloat(1.0)

            fillLayer.add(Animation.createLineAnimation(duration: duration), forKey: Animation.Key.line)
            circleLayer.add(Animation.createRotationAnimation(duration: duration), forKey: Animation.Key.circle)
        }, completion: { [weak self] in
            guard let strongSelf = self else { return }

            if strongSelf.circleAnimation {
                strongSelf.runAnimation()
            } else if strongSelf.checkmarkAnimation {
                strongSelf.circleLayer.opacity = 0

                strongSelf.layer.addSublayer(strongSelf.checkmarkLayer)
                strongSelf.checkmarkLayer.strokeEnd = 1

                CATransaction.animate(block: {
                    let animation = Animation.createCheckmarkAnimation(duration: 1.0)
                    strongSelf.checkmarkLayer.add(animation, forKey: Animation.Key.checkmark)
                }, completion: {
                    strongSelf.checkmarkAnimation = false
                    strongSelf.circleAnimation = false

                    strongSelf.completion?()
                    strongSelf.completion = nil

                    strongSelf.layer.removeAllAnimations()
                })
            }
        })
    }

    private func draw(backgroundLayer layer: CAShapeLayer) {
        let path = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: 0, endAngle: 2*CGFloat.pi, clockwise: true)
        layer.path = path.cgPath
    }

    private func draw(fillLayer layer: CAShapeLayer) {

        let startAngle = (-CGFloat.pi/2)
        let endAngle = 2 * CGFloat.pi + startAngle

        let path = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        layer.path = path.cgPath
    }

    private func draw(checkmarkLayer layer: CAShapeLayer) {
        let scale = frame.width / 100
        let centerX = frame.size.width / 2
        let centerY = frame.size.height / 2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: centerX - 23 * scale, y: centerY - 1 * scale))
        path.addLine(to: CGPoint(x: centerX - 6 * scale, y: centerY + 15.9 * scale))
        path.addLine(to: CGPoint(x: centerX + 22.8 * scale, y: centerY - 13.4 * scale))

        layer.path = path
    }

    private func draw(circleLayer layer: CAShapeLayer) {
        let halfSize: CGFloat = circleWidth / 2.0

        let rect = CGRect(x: -halfSize, y: -((frame.size.width / 2.0) + (halfSize / 2)), width: circleWidth, height: circleWidth)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: halfSize)

        layer.path = path.cgPath
        layer.position = CGPoint(x: self.layer.frame.width / 2.0, y: self.layer.frame.height / 2.0)
    }

    override func layoutSublayers(of layer: CALayer) {
        draw(backgroundLayer: backgroundLayer)
        draw(fillLayer: fillLayer)
        draw(circleLayer: circleLayer)
        draw(checkmarkLayer: checkmarkLayer)
    }
}

extension CircularLoadingIndicatorView {

    enum Animation {
        enum Key {
            static let line = "lineAnimation"
            static let circle = "circleRotationAnimation"
            static let checkmark = "checkmarkAnimation"
        }

        static func createLineAnimation(duration: Double) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1.0
            animation.duration = duration
            animation.isRemovedOnCompletion = true
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

            return animation
        }

        static func createRotationAnimation(duration: Double, timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.byValue = NSNumber(value: 2 * Double.pi)
            animation.duration = duration
            animation.timingFunction = timingFunction
            animation.isRemovedOnCompletion = true

            return animation
        }

        static func createCheckmarkAnimation(duration: Double) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.duration = duration
            animation.isRemovedOnCompletion = true

            return animation
        }
    }
}

extension CATransaction {
    static func animate(block: () -> Void, completion: (() -> Void)? = nil) {
        CATransaction.begin()

        if let completion = completion {
            CATransaction.setCompletionBlock(completion)
        }

        block()

        CATransaction.commit()
    }
}
