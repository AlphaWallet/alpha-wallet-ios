//
//  TransitionButton.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import Foundation
import UIKit

/**
Stop animation style of the `TransitionButton`.
 - normal: just revert the button to the original state.
 - shake: revert the button to original state and make a shaoe animation, useful to reflect that something went wrong
 */
public enum StopAnimationStyle {
    case normal
    case shake
}

/// UIButton subclass for loading and transition animation. Useful for network based application or where you need to animate an action button while doing background tasks.
@IBDesignable open class TransitionButton: UIButton, CAAnimationDelegate {
    var shrinkBorderColor: UIColor = AlphaWallet.Configuration.Color.Semantic.transitionButtonShrinkBorder
    var shrinkBorderWidth: CGFloat = 3.0
    var shrinkBackgroundColor: UIColor = AlphaWallet.Configuration.Color.Semantic.defaultButtonBackground

    private var cachedTitle: String?
    private var cachedImage: UIImage?
    private var cachedBackgroundImage: UIImage?
    private var cachedBorderWidth: CGFloat?
    private var cachedBorderColor: CGColor?

    private let shrinkCurve: CAMediaTimingFunction = CAMediaTimingFunction(name: .linear)
    private let expandCurve: CAMediaTimingFunction = CAMediaTimingFunction(controlPoints: 0.95, 0.02, 1, 0.05)
    private let shrinkDuration: CFTimeInterval = 0.3

    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.borderWidth = shrinkBorderWidth
    }

    required public init?(coder aDecoder: NSCoder) {
        return nil
    }

    /**
     Start animating the button, before starting a task, example: before a network call.
     - Parameter completion: a callback closure to be called once the animation finished.
     */
    open func startAnimation(completion: (() -> Void)? = nil) {
        isUserInteractionEnabled = false

        cachedTitle = title(for: .normal)
        cachedImage = image(for: .normal)
        cachedBackgroundImage = backgroundImage(for: .normal)
        cachedBorderWidth = layer.borderWidth
        cachedBorderColor = layer.borderColor

        setTitle("", for: .normal)
        setImage(nil, for: .normal)

        UIView.animate(withDuration: 0.2, animations: {
            self.layer.cornerRadius = self.frame.height / 2
        }, completion: { _ -> Void in
            self.shrink(completion: completion)
        })
    }

    /**
     Stop animating the button.
     - Parameter animationStyle: the style of the stop animation.
     - Parameter completion: a callback closure to be called once the animation finished.
     */
    open func stopAnimation(animationStyle: StopAnimationStyle = .normal, completion: (() -> Void)? = nil) {
        switch animationStyle {
        case .normal:
            self.setOriginalState(completion: completion)
        case .shake:
            self.setOriginalState(completion: {
                self.shakeAnimation(completion: completion)
            })
        }
    }

    private func shakeAnimation(completion: (() -> Void)?) {
        let animation = CAKeyframeAnimation(keyPath: "position")
        let point = layer.position
        animation.values = [
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x - 10), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x + 10), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x - 10), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x + 10), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x - 10), y: CGFloat(point.y))),
            NSValue(cgPoint: CGPoint(x: CGFloat(point.x + 10), y: CGFloat(point.y))),
            NSValue(cgPoint: point)
        ]

        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.duration = 0.7
        layer.position = point

        CATransaction.animate(block: {
            layer.add(animation, forKey: animation.keyPath)
        }, completion: completion)
    }

    private func setOriginalState(completion: (() -> Void)?) {
        animateToOriginalWidth(completion: completion)

        setTitle(cachedTitle, for: .normal)
        setImage(cachedImage, for: .normal)
        setBackgroundImage(cachedBackgroundImage, for: .normal)

        isUserInteractionEnabled = true
        layer.cornerRadius = cornerRadius
    }

    private func animateToOriginalWidth(completion: (() -> Void)?) {
        let animation1 = createShrinkAnimation(from: bounds.height, to: bounds.width)
        let animation2 = createBorderColorAnimation(cachedBorderColor)
        layer.borderColor = cachedBorderColor

        let animation3 = createBorderWidthAnimation(cachedBorderWidth)
        layer.borderWidth = cachedBorderWidth ?? 0.0

        let animation4 = CABasicAnimation(keyPath: "backgroundColor")
        animation4.toValue = shrinkBackgroundColor
        animation4.duration = shrinkDuration
        animation4.timingFunction = shrinkCurve
        animation4.isRemovedOnCompletion = false

        setBackgroundImage(cachedBackgroundImage, for: .normal)

        CATransaction.animate(block: {
            layer.add(animation1, forKey: animation1.keyPath)
            layer.add(animation2, forKey: animation2.keyPath)
            layer.add(animation3, forKey: animation3.keyPath)
        }, completion: completion)
    }

    private func createBorderWidthAnimation(_ value: CGFloat?) -> CABasicAnimation {
        let animation: CABasicAnimation = CABasicAnimation(keyPath: "borderWidth")
        animation.fromValue = layer.borderWidth
        animation.toValue = value
        animation.duration = shrinkDuration
        animation.timingFunction = shrinkCurve
        animation.isRemovedOnCompletion = false

        return animation
    }

    private func createBorderColorAnimation(_ color: CGColor?) -> CABasicAnimation {
        let animation: CABasicAnimation = CABasicAnimation(keyPath: "borderColor")
        animation.fromValue = layer.borderColor
        animation.toValue = color
        animation.duration = shrinkDuration
        animation.timingFunction = shrinkCurve
        animation.isRemovedOnCompletion = false

        return animation
    }

    private func createShrinkAnimation(from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = shrinkDuration
        animation.timingFunction = shrinkCurve
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        return animation
    }

    private func shrink(completion: (() -> Void)?) {
        let animation1 = createShrinkAnimation(from: frame.width, to: frame.height)
        let animation2 = createBorderColorAnimation(shrinkBorderColor.cgColor)
        layer.borderColor = shrinkBorderColor.cgColor

        let animation3 = createBorderWidthAnimation(shrinkBorderWidth)
        layer.borderWidth = shrinkBorderWidth

        let animation4 = CABasicAnimation(keyPath: "backgroundColor")
        animation4.toValue = shrinkBackgroundColor.cgColor
        animation4.duration = shrinkDuration
        animation4.timingFunction = shrinkCurve
        animation4.isRemovedOnCompletion = false

        setBackgroundColor(shrinkBackgroundColor, forState: .normal)

        CATransaction.animate(block: {
            layer.add(animation1, forKey: animation1.keyPath)
            layer.add(animation2, forKey: animation2.keyPath)
            layer.add(animation3, forKey: animation3.keyPath)
        }, completion: completion)
    }
}
