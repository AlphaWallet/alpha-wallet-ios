// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore

protocol PaymentCoordinatorDelegate: class, CanOpenURL {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {
    private let session: WalletSession
    private let flow: PaymentFlow
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let tokenHolders: [TokenHolder]!
    private let assetDefinitionStore: AssetDefinitionStore

    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    init(
            navigationController: UINavigationController = UINavigationController(),
            flow: PaymentFlow,
            session: WalletSession,
            keystore: Keystore,
            storage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            tokenHolders: [TokenHolder] = [],
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.flow = flow
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.tokenHolders = tokenHolders
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        switch (flow, session.account.type) {
        case (.send(let type), .real(let account)):
            let coordinator = SendCoordinator(
                transferType: type,
                navigationController: navigationController,
                session: session,
                keystore: keystore,
                storage: storage,
                account: account,
                ethPrice: ethPrice,
                tokenHolders: tokenHolders!,
                assetDefinitionStore: assetDefinitionStore
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.request, _):
            let coordinator = RequestCoordinator(
                navigationController: navigationController,
                session: session
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.send, .watch):
            // This case should be returning an error inCoordinator. Improve this logic into single piece.
            break
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancel() {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: SendCoordinatorDelegate {
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
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
