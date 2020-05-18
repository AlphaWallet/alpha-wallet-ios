// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIView {
    
    func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize = .zero, radius: CGFloat = 1, scale: Bool = true, shouldRasterize: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offSet
        layer.shadowRadius = radius

        layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        layer.shouldRasterize = shouldRasterize
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    
    func anchorsConstraint(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    func anchorsConstraint(to view: UIView, margin: CGFloat) -> [NSLayoutConstraint] {
        return anchorsConstraint(to: view, edgeInsets: .init(top: margin, left: margin, bottom: margin, right: margin))
    }

    var layoutGuide: UILayoutGuide {
        if #available(iOS 11, *) {
            return safeAreaLayoutGuide
        } else {
            return layoutMarginsGuide
        }
    }

    static func spacer(height: CGFloat = 1, backgroundColor: UIColor = .clear) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backgroundColor
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height),
        ])
        return view
    }

    static func spacerWidth(_ width: CGFloat = 1, backgroundColor: UIColor = .clear, alpha: CGFloat = 1, flexible: Bool = false) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backgroundColor
        view.alpha = alpha

        if flexible {
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
            ])
        } else {
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: width),
            ])
        }

        return view
    }

    var centerRect: CGRect {
        return CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
    }

    //Have to recreate UIMotionEffect every time, after `layoutSubviews()` complete
    func setupParallaxEffect(forView view: UIView, max: CGFloat) {
        view.motionEffects.forEach { view.removeMotionEffect($0) }

        let min = max
        let max = -max

        let xMotion = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        xMotion.minimumRelativeValue = min
        xMotion.maximumRelativeValue = max

        let yMotion = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        yMotion.minimumRelativeValue = min
        yMotion.maximumRelativeValue = max

        let motionEffectGroup = UIMotionEffectGroup()
        motionEffectGroup.motionEffects = [xMotion, yMotion]

        view.addMotionEffect(motionEffectGroup)
    }

    func firstSubview<T>(ofType type: T.Type) -> T? {
        if let viewFound = subviews.first(where: { $0 is T }) {
            return viewFound as? T
        }
        for each in subviews {
            if let viewFound = each.firstSubview(ofType: T.self) {
                return viewFound
            }
        }
        return nil
    }
}
