// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol AcceptAuthRequestCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: AcceptAuthRequestCoordinator, didComplete result: AuthRequestResult)
}

class AcceptAuthRequestCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    private let analytics: AnalyticsLogger
    private let authRequest: AlphaWallet.WalletConnect.AuthRequest
    private let navigationController: UINavigationController
    private lazy var viewModel = AcceptAuthRequestViewModel(authRequest: authRequest, analytics: analytics)
    private lazy var rootViewController: AcceptAuthRequestViewController = {
        let viewController = AcceptAuthRequestViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()
    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
    }()

    weak var delegate: AcceptAuthRequestCoordinatorDelegate?

    init(analytics: AnalyticsLogger, authRequest: AlphaWallet.WalletConnect.AuthRequest, navigationController: UINavigationController) {
        self.analytics = analytics
        self.authRequest = authRequest
        self.navigationController = navigationController
    }

    func start() {
        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

        rootViewController.reloadView()
    }

    func close(completion: @escaping () -> Void) {
        hostViewController.dismiss(animated: true, completion: completion)
    }
}

extension AcceptAuthRequestCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.coordinator(self, didComplete: .cancel)
    }
}

extension AcceptAuthRequestCoordinator: AcceptAuthRequestViewControllerDelegate {
    func didInvalidateLayout(in controller: AcceptAuthRequestViewController) {
        hostViewController.invalidateLayout()
    }

    func changeConnectionServerSelected(in controller: AcceptAuthRequestViewController) {
        //no-op
    }

    func controller(_ controller: AcceptAuthRequestViewController, continueButtonTapped sender: UIButton) {
        viewModel.logAuthAccept()
        UINotificationFeedbackGenerator.show(feedbackType: .success)
        close(completion: {
            self.delegate?.coordinator(self, didComplete: .accept(self.viewModel.server))
        })
    }

    func didClose(in controller: AcceptAuthRequestViewController) {
        viewModel.logAuthCancel()
        close(completion: {
            self.delegate?.coordinator(self, didComplete: .cancel)
        })
    }
}
