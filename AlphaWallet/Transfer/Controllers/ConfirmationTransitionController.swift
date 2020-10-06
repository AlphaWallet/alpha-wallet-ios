//
//  ConfirmationTransitionController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.07.2020.
//

import UIKit

protocol UpdatablePreferredContentSizeContainer {
    var updatablePreferredContentSize: UpdatablePreferredContentSize? { get }
}

protocol UpdatablePreferredContentSize {
    var updatePreferredContentSizeAnimated: Bool { get set }
}

extension UINavigationController: UpdatablePreferredContentSizeContainer {
    var updatablePreferredContentSize: UpdatablePreferredContentSize? {
        return viewControllers.compactMap { $0 as? UpdatablePreferredContentSize }.first
    }
}

class ConfirmationTransitionController: NSObject {

    //NOTE: Need to retain self until dismissal because UIKit won't.
    private var selfRetainer: ConfirmationTransitionController? = nil
    private let sourceViewController: UIViewController
    private let destinationViewController: UIViewController
    private let presenter = Presenter()
    private let dismisser = Dismisser()

    init(sourceViewController: UIViewController, destinationViewController: UIViewController) {
        self.sourceViewController = sourceViewController

        self.destinationViewController = UINavigationController(rootViewController: destinationViewController)
        self.destinationViewController.preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
    }

    func start() {
        selfRetainer = self
        destinationViewController.modalPresentationStyle = .overFullScreen
        destinationViewController.transitioningDelegate = self

        sourceViewController.present(destinationViewController, animated: true)
    }

}

extension ConfirmationTransitionController: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presenter
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        selfRetainer = nil
        return dismisser
    }

    private class Presenter: NSObject, UIViewControllerAnimatedTransitioning {

        private var preferredContentSizeObservation: NSKeyValueObservation?

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.5
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            let transitionContainerView = transitionContext.containerView
            guard let toView = transitionContext.view(forKey: .to) else { return }
            guard let toViewController = transitionContext.viewController(forKey: .to) else { return }

            toView.translatesAutoresizingMaskIntoConstraints = false
            transitionContainerView.addSubview(toView)
            transitionContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.6)

            NSLayoutConstraint.activate([
                transitionContainerView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: toView.safeAreaLayoutGuide.bottomAnchor, constant: 0),
                transitionContainerView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: toView.safeAreaLayoutGuide.leadingAnchor, constant: 0),
                transitionContainerView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: toView.safeAreaLayoutGuide.trailingAnchor, constant: 0)
            ])

            let heightConstraint = toView.heightAnchor.constraint(equalToConstant: toViewController.preferredContentSize.height)
            heightConstraint.isActive = true

            preferredContentSizeObservation = toViewController.observe(\.preferredContentSize, options: [.initial, .new]) { object, _ in
                guard object.preferredContentSize.height != heightConstraint.constant else { return }

                let fillScreenPercentage = object.preferredContentSize.height / transitionContainerView.bounds.height
                var height: CGFloat
                if fillScreenPercentage >= 0.9 {
                    height = transitionContainerView.bounds.height
                } else {
                    height = object.preferredContentSize.height
                }

                heightConstraint.constant = height

                guard let preferredContentSizeContainer = toViewController as? UpdatablePreferredContentSizeContainer, let controller = preferredContentSizeContainer.updatablePreferredContentSize else { return }

                if controller.updatePreferredContentSizeAnimated {
                    UIView.animate(withDuration: 0.25) {
                        transitionContainerView.layoutIfNeeded()
                    }
                }
            }

            transitionContainerView.layoutIfNeeded()

            let originalOriginY = toView.frame.origin.y
            toView.frame.origin.y += transitionContainerView.frame.height - toView.frame.minY
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                toView.frame.origin.y = originalOriginY
            }, completion: { completed in
                transitionContext.completeTransition(completed)
            })
        }
    }

    private class Dismisser: NSObject, UIViewControllerAnimatedTransitioning {

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.2
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            let container = transitionContext.containerView
            guard let fromView = transitionContext.view(forKey: .from) else { return }

            UIView.animate(withDuration: 0.2, animations: {
                fromView.frame.origin.y += container.frame.height - fromView.frame.minY
            }, completion: { completed in
                transitionContext.completeTransition(completed)
            })
        }
    }
}
