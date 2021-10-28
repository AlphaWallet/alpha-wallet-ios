// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIView {
    static func tableFooterToRemoveEmptyCellSeparators() -> UIView {
      return .init()
    }

    static var tokenSymbolBackgroundImageCache: ThreadSafeDictionary<UIColor, UIImage> = .init()
    static func tokenSymbolBackgroundImage(backgroundColor: UIColor, contractAddress: AlphaWallet.Address) -> UIImage {
        if let cachedValue = tokenSymbolBackgroundImageCache[backgroundColor] {
            return cachedValue
        }
        let size = CGSize(width: 40, height: 40)
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(backgroundColor.cgColor)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        tokenSymbolBackgroundImageCache[backgroundColor] = image
        return image
    }
    static func tokenSymbolBackgroundImage(backgroundColor: UIColor) -> UIImage {
        if let cachedValue = tokenSymbolBackgroundImageCache[backgroundColor] {
            return cachedValue
        }
        let size = CGSize(width: 40, height: 40)
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(backgroundColor.cgColor)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        tokenSymbolBackgroundImageCache[backgroundColor] = image
        return image
    }

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

    func anchorsConstraintLessThanOrEqualTo(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(lessThanOrEqualTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }
    func anchorsConstraintGreaterThanOrEqualTo(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    func anchorsConstraint(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    func anchorsConstraintSafeArea(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    func anchorsConstraint(to view: UIView, margin: CGFloat) -> [NSLayoutConstraint] {
        return anchorsConstraint(to: view, edgeInsets: .init(top: margin, left: margin, bottom: margin, right: margin))
    }

    static func spacer(height: CGFloat = 1, backgroundColor: UIColor = .clear, flexible: Bool = false) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backgroundColor

        if flexible {
            NSLayoutConstraint.activate([
                view.heightAnchor.constraint(greaterThanOrEqualToConstant: height),
            ])
        } else {
            NSLayoutConstraint.activate([
                view.heightAnchor.constraint(equalToConstant: height),
            ])
        }
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
