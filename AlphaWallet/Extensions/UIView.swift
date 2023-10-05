// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension Array where Iterator.Element == NSLayoutConstraint {
    func configure(edgeInsets: UIEdgeInsets) {
        guard count == 4 else { return }

        let values: [CGFloat] = [edgeInsets.left, -edgeInsets.right, edgeInsets.top, -edgeInsets.bottom]
        for (index, each) in self.enumerated() {
            each.constant = values[index]
        }
    }
}

extension UIView {
    func sized(_ size: CGSize) -> [NSLayoutConstraint] {
        return [
            heightAnchor.constraint(equalToConstant: size.height),
            widthAnchor.constraint(equalToConstant: size.width)
        ]
    }

    static func tableFooterToRemoveEmptyCellSeparators() -> UIView {
      return .init()
    }

    func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize = .zero, radius: CGFloat = 1, scale: Bool = true, shouldRasterize: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offSet
        layer.shadowRadius = radius

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        layer.shouldRasterize = shouldRasterize
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
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

    func adjusted(adjusment: CGFloat = 15) -> UIView {
        return [.spacerWidth(adjusment), self, .spacerWidth(adjusment)].asStackView()
    }
}

extension UIView {
    static func separator(height: CGFloat = 1) -> UIView {
        return spacer(height: height, backgroundColor: Configuration.Color.Semantic.tableViewSeparator)
    }
}

extension UIView {

    var parentFloatingPanelController: FloatingPanelController? {
        var nextResponder: UIResponder? = self
        while nextResponder != nil {
            guard let floatingPanelController = nextResponder as? FloatingPanelController else {
                nextResponder = nextResponder?.next
                continue
            }

            return floatingPanelController
        }

        return nil
    }

    static var statusBarFrame: CGRect {
        return keyWindow?.windowScene?.statusBarManager?.statusBarFrame ?? .zero
    }

    static var keyWindow: UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }

    static func applyBlur(blurStyle: UIBlurEffect.Style = .extraLight, alpha: CGFloat = 1.0) {
        let blurEffect = UIBlurEffect(style: blurStyle)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = UIScreen.main.bounds
        blurEffectView.alpha = alpha
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.isUserInteractionEnabled = false

        blurView = blurEffectView
    }

    static func removeBlur() {
        blurView?.removeFromSuperview()
    }

    private(set) static var blurView: UIVisualEffectView? {
        get {
            UIWindow.keyWindow?.subviews.compactMap { $0 as? UIVisualEffectView }.last
        }

        set {
            guard let blurView = newValue else { return }
            UIWindow.keyWindow?.addSubview(blurView)
        }
    }
}

extension UIView {
    static func tableHeaderFooterViewSeparatorView() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        view.backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground

        return view
    }

    func anchorSeparatorToTop(to superView: UIView) -> [NSLayoutConstraint] {
        return [
            centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            widthAnchor.constraint(equalTo: superView.widthAnchor),
            heightAnchor.constraint(equalToConstant: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight),
            topAnchor.constraint(equalTo: superView.topAnchor)
        ]
    }

    func anchorSeparatorToBottom(to superView: UIView) -> [NSLayoutConstraint] {
        return [
            centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            widthAnchor.constraint(equalTo: superView.widthAnchor),
            heightAnchor.constraint(equalToConstant: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight),
            bottomAnchor.constraint(equalTo: superView.bottomAnchor)
        ]
    }
}
