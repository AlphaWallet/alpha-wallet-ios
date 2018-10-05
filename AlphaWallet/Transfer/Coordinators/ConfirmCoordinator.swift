// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore
import Result

protocol ConfirmCoordinatorDelegate: class {
    func didCancel(in coordinator: ConfirmCoordinator)
}

class ConfirmCoordinator: Coordinator {
    private let session: WalletSession
    private let account: Account
    private let keystore: Keystore
    private let configurator: TransactionConfigurator
    private let type: ConfirmType

    let navigationController: UINavigationController
    var didCompleted: ((Result<ConfirmResult, AnyError>) -> Void)?
    var coordinators: [Coordinator] = []
    weak var delegate: ConfirmCoordinatorDelegate?

    init(
        navigationController: UINavigationController = NavigationController(),
        session: WalletSession,
        configurator: TransactionConfigurator,
        keystore: Keystore,
        account: Account,
        type: ConfirmType
    ) {
        self.navigationController = navigationController
        self.session = session
        self.configurator = configurator
        self.keystore = keystore
        self.account = account
        self.type = type
    }

    func start() {
        let controller = ConfirmPaymentViewController(
            session: session,
            keystore: keystore,
            configurator: configurator,
            confirmType: type
        )
        controller.didCompleted = { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let data):
                strongSelf.didCompleted?(.success(data))
            case .failure(let error):
                strongSelf.navigationController.displayError(error: error)
            }
        }
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))

        navigationController.viewControllers = [controller]
    }

    @objc func dismiss() {
        didCompleted?(.failure(AnyError(DAppError.cancelled)))
        delegate?.didCancel(in: self)
    }
}
