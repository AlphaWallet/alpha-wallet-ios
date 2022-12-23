//
//  SupportCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.11.2022.
//

import Foundation
import Combine
import AlphaWalletFoundation

protocol SupportCoordinatorDelegate: AnyObject, CanOpenURL {
    func didClose(in coordinator: SupportCoordinator)
}

class SupportCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let analytics: AnalyticsLogger
    private let resolver = ContactUsEmailResolver()

    var coordinators: [Coordinator] = []
    weak var delegate: SupportCoordinatorDelegate?

    init(navigationController: UINavigationController, analytics: AnalyticsLogger) {
        self.navigationController = navigationController
        self.analytics = analytics
    }

    func start() {
        let viewModel = SupportViewModel(analytics: analytics)
        let viewController = SupportViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }
}

extension SupportCoordinator: SupportViewControllerDelegate {
    func supportActionSelected(in viewController: SupportViewController, action: SupportViewModel.SupportAction) {
        switch action {
        case .openUrl(let provider):
            if let deepLinkURL = provider.deepLinkURL, UIApplication.shared.canOpenURL(deepLinkURL) {
                UIApplication.shared.open(deepLinkURL, options: [:], completionHandler: .none)
            } else {
                delegate?.didPressOpenWebPage(provider.remoteURL, in: viewController)
            }
        case .shareAttachments(let attachments):
            resolver.present(from: viewController, attachments: attachments)
        }
    }

    func didClose(in viewController: SupportViewController) {
        delegate?.didClose(in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWalletFoundation.AlphaWallet.Address, server: AlphaWalletFoundation.RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
