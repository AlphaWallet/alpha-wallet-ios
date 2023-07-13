// Copyright SIX DAY LLC. All rights reserved.
import Foundation
import UIKit
import StoreKit
import AlphaWalletFoundation

class HelpUsCoordinator: Coordinator {
    private let hostViewController: UIViewController
    private let appTracker: AppTracker
    private let viewModel = HelpUsViewModel()
    private let analytics: AnalyticsLogger

    var coordinators: [Coordinator] = []

    init(
        hostViewController: UIViewController = UIViewController(),
        appTracker: AppTracker = AppTracker(),
        analytics: AnalyticsLogger
    ) {
        self.hostViewController = hostViewController
        self.appTracker = appTracker
        self.analytics = analytics
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
        if Features.current.isAvailable(.isPromptForEmailListSubscriptionEnabled) && appTracker.launchCountForCurrentBuild > 3 && !appTracker.hasCompletedPromptForNewsletter {
            promptSubscribeToNewsletter()
        } else {
            rateUs()
        }
    }

    private func promptSubscribeToNewsletter() {
        guard !appTracker.hasCompletedPromptForNewsletter else { return }
        appTracker.hasCompletedPromptForNewsletter = true

        let controller = CollectUsersEmailViewController()
        controller._delegate = self
        controller.configure(viewModel: .init())

        hostViewController.present(controller, animated: true)
    }

    private func rateUs() {
        SKStoreReviewController.requestReview()
        appTracker.completedRating = true
    }

    private func wellDone() {
        let controller = WellDoneViewController()
        controller.navigationItem.title = viewModel.title
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.doneBarButton(self, selector: #selector(dismissButtonSelected))
        controller.delegate = self
        let nav = NavigationController(rootViewController: controller)
        nav.makePresentationFullScreenForiOS13Migration()
        hostViewController.present(nav, animated: true)
    }

    @objc private func dismissButtonSelected() {
        hostViewController.dismiss(animated: true, completion: nil)
    }

    private func presentSharing(in viewController: UIViewController, from sender: UIView) {
        let activityViewController = UIActivityViewController(
            activityItems: viewModel.activityItems,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.centerRect
        activityViewController.completionWithItemsHandler = { [weak self] _, isShared, _, _ in
            self?.logSharedAppWhenPrompted(isShared)
        }
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

extension HelpUsCoordinator: CollectUsersEmailViewControllerDelegate {
    func didClose(in viewController: CollectUsersEmailViewController) {
        logEmailNewsletterSubscription(isSubscribed: false)
    }

    func didFinish(in viewController: CollectUsersEmailViewController, email: String) {
        if email.isEmpty {
            logEmailNewsletterSubscription(isSubscribed: false)
        } else {
            EmailList(listSpecificKey: Constants.Credentials.mailChimpListSpecificKey).subscribe(email: email)
            logEmailNewsletterSubscription(isSubscribed: true)
        }
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
        analytics.log(action: Analytics.Action.subscribeToEmailNewsletter, properties: [Analytics.Properties.isAccepted.rawValue: isSubscribed])
    }

    private func logSharedAppWhenPrompted(_ isShared: Bool) {
        analytics.log(action: Analytics.Action.sharedAppWhenPrompted, properties: [Analytics.Properties.isAccepted.rawValue: isShared])
    }
}
