// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol PaymentCoordinatorDelegate: class, CanOpenURL {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {
    private let session: WalletSession
    let flow: PaymentFlow
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator

    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    private var shouldRestoreNavigationBarIsHiddenState: Bool
    private var latestNavigationStackViewController: UIViewController?

    init(
            navigationController: UINavigationController,
            flow: PaymentFlow,
            session: WalletSession,
            keystore: Keystore,
            storage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.navigationController = navigationController
        self.session = session
        self.flow = flow
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator

        shouldRestoreNavigationBarIsHiddenState = navigationController.navigationBar.isHidden
        latestNavigationStackViewController = navigationController.viewControllers.last
    }

    func start() {
        if shouldRestoreNavigationBarIsHiddenState {
            self.navigationController.setNavigationBarHidden(false, animated: true)
        }

        switch (flow, session.account.type) {
        case (.send(let type), .real):
            let coordinator = SendCoordinator(
                transactionType: type,
                navigationController: navigationController,
                session: session,
                keystore: keystore,
                storage: storage,
                ethPrice: ethPrice,
                assetDefinitionStore: assetDefinitionStore,
                analyticsCoordinator: analyticsCoordinator
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.request, _):
            let coordinator = RequestCoordinator(navigationController: navigationController, account: session.account)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.send, .watch):
            // This case should be returning an error inCoordinator. Improve this logic into single piece.
            break
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func cancel() {
        delegate?.didCancel(in: self)
    }

    func dismiss(animated: Bool) {
        if shouldRestoreNavigationBarIsHiddenState {
            navigationController.setNavigationBarHidden(true, animated: animated)
        }

        if let viewController = latestNavigationStackViewController {
            navigationController.popToViewController(viewController, animated: animated)
        } else {
            navigationController.popToRootViewController(animated: animated)
        }
    }
}

extension PaymentCoordinator: SendCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: SendCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func didCancel(in coordinator: SendCoordinator) {
        removeCoordinator(coordinator)
        cancel()
    }
}

extension PaymentCoordinator: RequestCoordinatorDelegate {
    func didCancel(in coordinator: RequestCoordinator) {
        removeCoordinator(coordinator)
        cancel()
    }
}

extension PaymentCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
