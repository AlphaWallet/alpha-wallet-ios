// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore

protocol PaymentCoordinatorDelegate: class {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {

    let session: WalletSession
    weak var delegate: PaymentCoordinatorDelegate?

    let flow: PaymentFlow
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController
    let keystore: Keystore
    let storage: TokensDataStore
    let ethPrice: Subscribable<Double>
    let ticketHolders: [TokenHolder]!

    init(
        navigationController: UINavigationController = UINavigationController(),
        flow: PaymentFlow,
        session: WalletSession,
        keystore: Keystore,
        storage: TokensDataStore,
        ethPrice: Subscribable<Double>,
        ticketHolders: [TokenHolder] = []
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.flow = flow
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.ticketHolders = ticketHolders
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
                ticketHolders: ticketHolders!
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
