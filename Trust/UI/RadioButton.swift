//
//  RadioButton.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

@IBDesignable
class RadioButton: UIButton {

    @IBInspectable
    var space: CGFloat = 8 {
        didSet {
            self.setNeedsDisplay()
        }
    }

    @IBInspectable
    var buttonColor: UIColor = UIColor.gray {
        didSet {
            self.setNeedsDisplay()
        }
    }

    @IBInspectable
    var isOn: Bool = false {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override
    func draw(_ rect: CGRect) {
        self.contentMode = .scaleAspectFill
        drawCircles(rect: rect)
    }

    func drawCircles(rect: CGRect) {
        var path = UIBezierPath()
        path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))

        let circleLayer = CAShapeLayer()
        circleLayer.path = path.cgPath
        circleLayer.lineWidth = 3
        circleLayer.strokeColor = buttonColor.cgColor
        circleLayer.fillColor = UIColor.white.cgColor
        layer.addSublayer(circleLayer)

        if isOn {
            let innerCircleLayer = CAShapeLayer()
            let rectForInnerCircle = CGRect(x: space, y: space, width: rect.width - 2 * space, height: rect.height - 2 * space)
            innerCircleLayer.path = UIBezierPath(ovalIn: rectForInnerCircle).cgPath
            innerCircleLayer.fillColor = buttonColor.cgColor
            layer.addSublayer(innerCircleLayer)
        }
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.main.nativeScale
    }

    override
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isOn = !isOn
        self.setNeedsDisplay()
    }
}
