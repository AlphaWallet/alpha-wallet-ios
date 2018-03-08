//
//  NumberStepper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

@IBDesignable
class NumberStepper: UIControl {

    @IBInspectable public var stepValue: Int = 1
    @IBInspectable public var minimumValue: Int = 0
    @IBInspectable public var maximumValue: Int = 100
    @IBInspectable public var showIntegerIfDoubleIsInteger: Bool = true

    @IBInspectable
    public var value: Int = 0 {
        didSet {
            label.text = String(value)
            if oldValue != value {
                sendActions(for: .valueChanged)
            }
        }
    }

    @IBInspectable
    public var buttonsTextColor: UIColor = UIColor.white {
        didSet {
            for button in [leftButton, rightButton] {
                button.setTitleColor(buttonsTextColor, for: .normal)
            }
        }
    }

    @IBInspectable
    public var buttonsBackgroundColor: UIColor = UIColor(red: 0.21, green: 0.5, blue: 0.74, alpha: 1) {
        didSet {
            for button in [leftButton, rightButton] {
                button.backgroundColor = buttonsBackgroundColor
            }
            backgroundColor = buttonsBackgroundColor
        }
    }

    public var buttonsFont = UIFont(name: "AvenirNext-Bold", size: 20.0)! {
        didSet {
            for button in [leftButton, rightButton] {
                button.titleLabel?.font = buttonsFont
            }
        }
    }

    @IBInspectable
    public var labelTextColor: UIColor = UIColor.white {
        didSet {
            label.textColor = labelTextColor
        }
    }

    @IBInspectable
    public var labelBackgroundColor: UIColor = UIColor(red: 0.26, green: 0.6, blue: 0.87, alpha: 1) {
        didSet {
            label.backgroundColor = labelBackgroundColor
        }
    }

    public var labelFont = UIFont(name: "AvenirNext-Bold", size: 25.0)! {
        didSet {
            label.font = labelFont
        }
    }

    @IBInspectable
    public var labelCornerRadius: CGFloat = 0 {
        didSet {
            label.layer.cornerRadius = labelCornerRadius

        }
    }

    @IBInspectable override
    public var cornerRadius: CGFloat {
        didSet {
            layer.cornerRadius = cornerRadius
            clipsToBounds = true
        }
    }

    @IBInspectable override
    public var borderWidth: CGFloat {
        didSet {
            layer.borderWidth = borderWidth
            label.layer.borderWidth = borderWidth
        }
    }

    @IBInspectable override
    public var borderColor: UIColor! {
        didSet {
            layer.borderColor = borderColor.cgColor
            label.layer.borderColor = borderColor.cgColor
        }
    }

    @IBInspectable
    public var labelWidthWeight: CGFloat = 0.5 {
        didSet {
            labelWidthWeight = min(1, max(0, labelWidthWeight))
            setNeedsLayout()
        }
    }

    lazy var leftButton: UIButton = {
        let button = UIButton()
        button.setTitle("-", for: .normal)
        button.setTitleColor(self.buttonsTextColor, for: .normal)
        button.backgroundColor = self.buttonsBackgroundColor
        button.titleLabel?.font = self.buttonsFont
        button.addTarget(self, action: #selector(NumberStepper.leftButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchUpInside)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchUpOutside)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchCancel)
        return button
    }()

    lazy var rightButton: UIButton = {
        let button = UIButton()
        button.setTitle("+", for: .normal)
        button.setTitleColor(self.buttonsTextColor, for: .normal)
        button.backgroundColor = self.buttonsBackgroundColor
        button.titleLabel?.font = self.buttonsFont
        button.addTarget(self, action: #selector(NumberStepper.rightButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchUpInside)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchUpOutside)
        button.addTarget(self, action: #selector(NumberStepper.buttonTouchUp), for: .touchCancel)
        return button
    }()

    lazy var label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = String(self.value)
        label.textColor = self.labelTextColor
        label.backgroundColor = self.labelBackgroundColor
        label.font = self.labelFont
        label.layer.cornerRadius = self.labelCornerRadius
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true
        return label
    }()

    var labelOriginalCenter: CGPoint!
    var labelMaximumCenterX: CGFloat!
    var labelMinimumCenterX: CGFloat!

    enum StepperState {
        case Stable, ShouldIncrease, ShouldDecrease
    }

    var stepperState = StepperState.Stable {
        didSet {
            if stepperState != .Stable {
                updateValue()
            }
        }
    }

    required
    public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override
    public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func setup() {
        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(label)

        backgroundColor = buttonsBackgroundColor
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
        labelOriginalCenter = label.center
    }

    override
    public func layoutSubviews() {
        let buttonWidth = bounds.size.width * ((1 - labelWidthWeight) / 2)
        let labelWidth = bounds.size.width * labelWidthWeight

        leftButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: bounds.size.height)
        label.frame = CGRect(x: buttonWidth, y: 0, width: labelWidth, height: bounds.size.height)
        rightButton.frame = CGRect(x: labelWidth + buttonWidth, y: 0, width: buttonWidth, height: bounds.size.height)

        labelOriginalCenter = label.center
    }

    func updateValue() {
        if stepperState == .ShouldIncrease {
            value += stepValue
        } else if stepperState == .ShouldDecrease {
            value -= stepValue
        }
    }
}

extension NumberStepper {
    @objc
    func reset() {
        stepperState = .Stable
        leftButton.isEnabled = true
        rightButton.isEnabled = true
        label.isUserInteractionEnabled = true
    }
}

extension NumberStepper {
    @objc
    func leftButtonTouchDown(button: UIButton) {
        rightButton.isEnabled = false
        label.isUserInteractionEnabled = false
        if value != minimumValue {
            stepperState = .ShouldDecrease
        }
    }

    @objc
    func rightButtonTouchDown(button: UIButton) {
        leftButton.isEnabled = false
        label.isUserInteractionEnabled = false
        if value != maximumValue {
            stepperState = .ShouldIncrease
        }
    }

    @objc
    func buttonTouchUp(button: UIButton) {
        reset()
    }
}
