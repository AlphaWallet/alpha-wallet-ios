//
//  ProgressView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit

class CircularProgressView: UIView {

    private lazy var circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineWidth = lineWidth
        layer.strokeColor = circleLineColor.cgColor
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        return layer
    }()

    private lazy var progressCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = progressLineColor.cgColor
        layer.lineCap = .round
        layer.lineWidth = 5
        layer.strokeColor = progressLineColor.cgColor

        return layer
    }()

    private lazy var progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()

        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineWidth = lineWidth
        layer.strokeEnd = 0
        layer.strokeColor = progressLineColor.cgColor

        return layer
    }()

    var lineWidth: CGFloat = 3.0
    var progressLineColor: UIColor = Colors.appActionButtonGreen
    var circleLineColor: UIColor = R.color.mercury()!

    override init(frame: CGRect) {
        super.init(frame: frame)
        createCircularPath()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        createCircularPath()
    }

    private var circularPath: UIBezierPath {
        let center = CGPoint(x: frame.size.width / 2.0, y: frame.size.height / 2.0)
        return UIBezierPath(
            arcCenter: center,
            radius: frame.size.width / 2.0,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let circularPath = self.circularPath

        circleLayer.path = circularPath.cgPath
        progressLayer.path = circularPath.cgPath

        let radius: CGFloat = 5.0
        let side = 2.0 * radius
        let halfSide = side / 2

        let rotationPoint = CGPoint(x: layer.frame.width / 2.0, y: layer.frame.height / 2.0)

//        let width = layer.frame.width
//        let height = layer.frame.height
//        let minX = layer.frame.minX
//        let minY = layer.frame.minY

//        let anchorPoint = CGPoint(x: (rotationPoint.x - minX) / width, y: (rotationPoint.y - minY) / height)

        progressCircleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)//anchorPoint
        progressCircleLayer.position = rotationPoint//CGPoint(x: layer.frame.width / 2.0, y: layer.frame.width / 2.0)//layer.frame.height / 2.0)

//        let circleRect = CGRect(x: 0, y: 0, width: radius, height: radius)
//        progressCircleLayer.path = UIBezierPath(roundedRect: circleRect, cornerRadius: radius).cgPath
//        progressCircleLayer.path = UIBezierPath(ovalIn: circleRect).cgPath

//        let rect = CGRect(x: 0, y: 0, width: radius, height: radius)
//        progressCircleLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
        progressCircleLayer.path = UIBezierPath(
            arcCenter: rotationPoint,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        ).cgPath
    }

    private func createCircularPath() {
        layer.masksToBounds = false

        layer.addSublayer(circleLayer)
        layer.addSublayer(progressLayer)
        circleLayer.addSublayer(progressCircleLayer)
    }

    func progressAnimation(_ duration: TimeInterval = 2.5) {
        let circularProgressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circularProgressAnimation.duration = duration
        circularProgressAnimation.toValue = 1.0
        circularProgressAnimation.fillMode = .forwards
        circularProgressAnimation.isRemovedOnCompletion = false

        progressLayer.add(circularProgressAnimation, forKey: "progressAnim")

        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 1.0//-CGFloat.pi / 2
//        rotationAnimation.toValue = 3 * CGFloat.pi / 2
        rotationAnimation.duration = duration
        circularProgressAnimation.fillMode = .forwards
        rotationAnimation.repeatCount = Float.infinity

        progressCircleLayer.add(rotationAnimation, forKey: "UIView.kRotationAnimationKey")
    }
}
