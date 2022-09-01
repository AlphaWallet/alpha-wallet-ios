//
//  ModalViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.09.2021.
//

import UIKit
import AlphaWalletFoundation

protocol ModalViewControllerDelegate: class {
    func didDismiss(_ controller: ModalViewController)
    func didClose(_ controller: ModalViewController)
}

class ModalViewController: UINavigationController {

    private let viewController: _ModalViewController = {
        let viewController = _ModalViewController()
        return viewController
    }()

    var stackView: UIStackView {
        viewController.stackView
    }

    var scrollView: UIScrollView {
        viewController.scrollView
    }

    var footerStackView: UIStackView {
        viewController.footerStackView
    }

    weak var presentationDelegate: ModalViewControllerDelegate?

    //Implementing this instead of `init()`. The latter works with Xcode 13 + iOS 15, but crashes with Xcode 14 + iOS 12.4
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        viewControllers = [viewController]

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear

        viewController.delegate = self
        viewController.headerView.cornerRadius = 10
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        viewController.dismissViewAnimated(with: completion)
    }
}

extension ModalViewController: _ModalViewControllerDelegate {

    fileprivate func didDismiss(_ controller: _ModalViewController) {
        presentationDelegate?.didDismiss(self)
    }

    fileprivate func didClose(_ controller: _ModalViewController) {
        presentationDelegate?.didClose(self)
    }
}

private protocol _ModalViewControllerDelegate: AnyObject {
    func didDismiss(_ controller: _ModalViewController)
    func didClose(_ controller: _ModalViewController)
}

private struct ModalViewModel {
    var backgroundColor: UIColor = .clear
}

private class _ModalViewController: UIViewController {
    private lazy var viewModel = ModalViewModel()
    private (set) lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: "", isMinimalMode: true, swipeIndicationHidden: false))

    var stackView: UIStackView {
        scrollableContainerView.stackView
    }

    var scrollView: UIScrollView {
        scrollableContainerView.scrollView
    }

    private lazy var scrollableContainerView: ScrollableStackView = {
        let view = ScrollableStackView()
        UIKitFactory.decorateAsDefaultView(view)
        return view
    }()

    private var contentSizeObservation: NSKeyValueObservation?

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Configuration.Color.Semantic.overlayBackground
        view.alpha = 0

        let tap = UITapGestureRecognizer(target: self, action: #selector(closeButtonSelected))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        UIKitFactory.decorateAsDefaultView(view)
        view.cornerRadius = 12

        let subview = [
            headerView,
            scrollableContainerView,
            footerStackView
        ].asStackView(axis: .vertical)

        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        NSLayoutConstraint.activate([subview.anchorsConstraintSafeArea(to: view)])

        return view
    }()

    private lazy var heightConstraint: NSLayoutConstraint = {
        return containerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private lazy var bottomConstraint: NSLayoutConstraint = {
        containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private var allowPresentationAnimation: Bool = true
    private var allowDismissalAnimation: Bool = true
    let percentThreshold: CGFloat = 0.2
    private (set) var footerStackView: UIStackView = [].asStackView(axis: .vertical)
    private var initialTouchPoint: CGPoint?
    private lazy var keyboard = KeyboardChecker(self, resetHeightDefaultValue: 0)
    weak var delegate: _ModalViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)
        view.addSubview(backgroundView)
        view.addSubview(containerView)

        var fixContentHeightIphone8Constraint: [NSLayoutConstraint] = []
        switch AlphaWallet.Device.version {
        case .phone8Plus, .phone8:
            fixContentHeightIphone8Constraint = [scrollableContainerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)]
        case .simulator where AlphaWallet.Device.screen == .inches_4_7: //NOTE: Iphone8 simulator
            fixContentHeightIphone8Constraint = [scrollableContainerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)]
        default:
            break
        }

        NSLayoutConstraint.activate([
            backgroundView.anchorsConstraint(to: view),
            heightConstraint,
            bottomConstraint,
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ] + fixContentHeightIphone8Constraint)
        headerView.closeButton.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let strongSelf = self, strongSelf.allowDismissalAnimation else { return }

            let statusBarHeight = UIApplication.shared.firstKeyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            let footerHeight = strongSelf.footerStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height

            let headerHeight = DataEntry.Metric.TransactionConfirmation.headerHeight
            let contentHeight = scrollView.contentSize.height + footerHeight + headerHeight + UIApplication.shared.bottomSafeAreaHeight
            let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

            let fillScreenPercentage = strongSelf.heightConstraint.constant / strongSelf.view.bounds.height
            //NOTE: for iphone 8, phone8Plus for some reasons ScrollableStackView doesn't validate with its content height. only faced with `WhatsNewListingViewController`. Force set contentSize.height as constraints height.
            for each in fixContentHeightIphone8Constraint {
                each.constant = scrollView.contentSize.height
            }

            if fillScreenPercentage >= 0.9 {
                strongSelf.heightConstraint.constant = strongSelf.containerView.bounds.height
            } else {
                strongSelf.heightConstraint.constant = newHeight
            }
        }

        keyboard.constraints = [bottomConstraint]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        //NOTE: to display animation correctly we can take 'view.frame.height' and bottom view will smoothly slide up from button ;)
        bottomConstraint.constant = view.frame.height

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerHandler))
        view.addGestureRecognizer(pan)

        scrollView.panGestureRecognizer.addTarget(self, action: #selector(panGestureRecognizerHandler))
    }

    @objc private func panGestureRecognizerHandler(_ sender: UIPanGestureRecognizer) {

        let touchPoint = sender.location(in: self.view?.window)
        let flag: Bool = {
            guard let scrollView = sender.view as? UIScrollView else { return true }
            return scrollView.contentOffset.y <= 0
        }()

        let keyboardHostView: UIView? = UIApplication.shared.keyboardHostView
        //NOTE: Disable hiding keyboard with pan gesture, (as it doesn't work perfectly)
        guard keyboardHostView == nil else { return }

        let restorationHeight = keyboardHostView?.frame.height ?? 0

        func computeProgress(initialTouchPoint: CGPoint) -> (progress: CGFloat, alpha: CGFloat, translation: CGPoint) {
            let translation = CGPoint(x: 0, y: touchPoint.y - initialTouchPoint.y)
            let verticalMovement = translation.y / heightConstraint.constant
            let downwardMovement = fmaxf(Float(verticalMovement), 0.0)
            let downwardMovementPercent = fminf(downwardMovement, 1.0)
            let progress = CGFloat(downwardMovementPercent)

            return (progress: progress, alpha: 1 - progress, translation: translation)
        }

        func restoreStateAnimated(_ height: CGFloat, keyboardHostView: UIView?) {
            self.bottomConstraint.constant = height
            let newFrame = keyboardHostView.flatMap { view -> CGRect? in
                CGRect(x: 0, y: UIScreen.main.bounds.height - view.frame.height, width: view.frame.size.width, height: view.frame.size.height)
            }

            UIView.animate(withDuration: 0.3, animations: {
                self.view.layoutIfNeeded()

                keyboardHostView?.frame = newFrame ?? .zero
                self.backgroundView.alpha = 1
            })
        }

        if sender.state == .began && flag {
            initialTouchPoint = touchPoint
        } else if sender.state == .changed && flag {
            let _initialTouchPoint: CGPoint
            if let value = initialTouchPoint {
                _initialTouchPoint = value
            } else {
                initialTouchPoint = touchPoint
                _initialTouchPoint = touchPoint
            }

            let result = computeProgress(initialTouchPoint: _initialTouchPoint)
            let newFrame = keyboardHostView.flatMap { view -> CGRect? in
                CGRect(x: 0, y: (UIScreen.main.bounds.height - view.frame.height) + result.translation.y, width: view.frame.size.width, height: view.frame.size.height)
            }

            if result.translation.y > 0 {
                bottomConstraint.constant = result.translation.y - (keyboardHostView?.frame.height ?? 0)

                UIView.animate(withDuration: 0.1, animations: {
                    self.view.layoutIfNeeded()

                    keyboardHostView?.frame = newFrame ?? .zero
                    self.backgroundView.alpha = result.alpha
                })
            }
        } else if sender.state == .ended || sender.state == .cancelled {
            if let initialTouchPoint = initialTouchPoint {
                let result = computeProgress(initialTouchPoint: initialTouchPoint)

                if result.progress > percentThreshold {
                    bottomConstraint.constant = heightConstraint.constant

                    let newFrame = keyboardHostView.flatMap { view -> CGRect? in
                        CGRect(x: 0, y: UIScreen.main.bounds.height, width: view.frame.size.width, height: view.frame.size.height)
                    }

                    UIView.animate(withDuration: 0.3, animations: {
                        self.view.layoutIfNeeded()

                        keyboardHostView?.frame = newFrame ?? .zero
                        self.backgroundView.alpha = 0
                    }, completion: { _ in
                        self.dismiss(animated: false)
                        self.delegate?.didDismiss(self)
                    })
                } else {
                    restoreStateAnimated(restorationHeight, keyboardHostView: keyboardHostView)
                }

                self.initialTouchPoint = nil
            } else {
                restoreStateAnimated(restorationHeight, keyboardHostView: keyboardHostView)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
        keyboard.viewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentViewAnimated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
        }

        keyboard.viewWillDisappear()
    }

    private func presentViewAnimated() {
        guard allowPresentationAnimation else { return }
        allowPresentationAnimation = false

        bottomConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            self.backgroundView.alpha = 1
        }
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        guard allowDismissalAnimation else { return }
        allowDismissalAnimation = false

        bottomConstraint.constant = heightConstraint.constant

        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()
            self.backgroundView.alpha = 0
        }, completion: { _ in
            completion()
        })
    }

    @objc private func closeButtonSelected() {
        delegate?.didClose(self)
    }

    private func configure() {
        scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}
