// Copyright SIX DAY LLC. All rights reserved.
import Foundation
import UIKit
import StoreKit

class HelpUsCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let appTracker: AppTracker
    private let viewModel = HelpUsViewModel()
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []

    init(
        navigationController: UINavigationController = UINavigationController(),
        appTracker: AppTracker = AppTracker(),
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.appTracker = appTracker
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        switch appTracker.launchCountForCurrentBuild {
        case 6 where !appTracker.completedRating:
            rateUsOrSubscribeToNewsletter()
        case 12 where !appTracker.completedSharing:
            wellDone()
        default: break
        }
    }

    func rateUsOrSubscribeToNewsletter() {
        if Features.isPromptForEmailListSubscriptionEnabled && appTracker.launchCountForCurrentBuild > 3 && !appTracker.hasCompletedPromptForNewsletter {
            promptSubscribeToNewsletter()
        } else {
            rateUs()
        }
    }

    private func promptSubscribeToNewsletter() {
        guard !appTracker.hasCompletedPromptForNewsletter else { return }
        appTracker.hasCompletedPromptForNewsletter = true

        let controller = UIAlertController.alertController(title: R.string.localizable.emailListPromptTitle(), message: R.string.localizable.emailListPromptMessage(), style: .alert, in: navigationController)
        controller.addTextField { textField in
            textField.placeholder = R.string.localizable.emailListPromptEmailPlaceholder()
        }

        //Intentionally hold strong reference to self for UIAlertAction to work. Making `self` weak requires current coordinator to be retained; too easy to forgot
        let subscribeAction = UIAlertAction(title: R.string.localizable.emailListPromptSubscribeButtonTitle(), style: .default, handler: { [weak self] _ in
            guard let email = controller.textFields?.first?.text?.trimmed else { return }
            if email.isEmpty {
                self?.logEmailNewsletterSubscription(isSubscribed: false)
            } else {
                EmailList(listSpecificKey: Constants.Credentials.mailChimpListSpecificKey).subscribe(email: email)
                self?.logEmailNewsletterSubscription(isSubscribed: true)
            }
        })
        controller.addAction(subscribeAction)
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { [weak self] _ in
            self?.logEmailNewsletterSubscription(isSubscribed: false)
        }
        controller.addAction(cancelAction)
        navigationController.present(controller, animated: true, completion: nil)
    }

    private func rateUs() {
        SKStoreReviewController.requestReview()
        appTracker.completedRating = true
    }

    private func wellDone() {
        let controller = WellDoneViewController()
        controller.navigationItem.title = viewModel.title
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(dismiss))
        controller.delegate = self
        let nav = UINavigationController(rootViewController: controller)
        nav.makePresentationFullScreenForiOS13Migration()
        navigationController.present(nav, animated: true, completion: nil)
    }

    @objc private func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func presentSharing(in viewController: UIViewController, from sender: UIView) {
        let activityViewController = UIActivityViewController(
            activityItems: viewModel.activityItems,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.centerRect
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

extension HelpUsCoordinator: WellDoneViewControllerDelegate {
    func didPress(action: WellDoneAction, sender: UIView, in viewController: WellDoneViewController) {
        switch action {
        case .other:
            presentSharing(in: viewController, from: sender)
        }

        appTracker.completedSharing = true
    }
}

// MARK: Analytics
extension HelpUsCoordinator {
    private func logEmailNewsletterSubscription(isSubscribed: Bool) {
        analyticsCoordinator.log(action: Analytics.Action.subscribeToEmailNewsletter, properties: [Analytics.Properties.isAccepted.rawValue: isSubscribed])
    }
}