// Copyright © 2023 Stormbird PTE. LTD.

import UIKit

extension UIView {
    public func anchorsConstraintLessThanOrEqualTo(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(lessThanOrEqualTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    public func anchorsConstraintGreaterThanOrEqualTo(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    public func anchorsConstraint(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    public func anchorsIgnoringBottomSafeArea(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    public func anchorsConstraintSafeArea(to view: UIView, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: edgeInsets.left),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -edgeInsets.right),
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -edgeInsets.bottom),
        ]
    }

    public func anchorsConstraint(to view: UIView, margin: CGFloat) -> [NSLayoutConstraint] {
        return anchorsConstraint(to: view, edgeInsets: .init(top: margin, left: margin, bottom: margin, right: margin))
    }

}

///This let us do this do effectively this:
///
///NSLayoutConstraint.activate([
///    constraintsArray1,
///    constraintsArray2,
///    constraint3,
///    constraint4,
///    constraint5,
///])
///
///Alternatives involve appending of arrays which ends up with code that is hard to indent
public protocol LayoutConstraintsWrapper {
    var constraints: [NSLayoutConstraint] { get }
}

extension Array: LayoutConstraintsWrapper where Element: NSLayoutConstraint {
    public var constraints: [NSLayoutConstraint] {
        return self
    }
}

extension NSLayoutConstraint: LayoutConstraintsWrapper {
    public var constraints: [NSLayoutConstraint] {
        return [self]
    }
}

extension NSLayoutConstraint {
    public class func activate(_ constraints: [LayoutConstraintsWrapper]) {
        activate(constraints.flatMap { $0.constraints })
    }
}
