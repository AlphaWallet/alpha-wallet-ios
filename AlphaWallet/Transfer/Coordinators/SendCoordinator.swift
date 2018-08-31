// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore

protocol SendCoordinatorDelegate: class {
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {

    let transferType: TransferType
    let session: WalletSession
    let account: Account
    let navigationController: UINavigationController
    let keystore: Keystore
    let storage: TokensDataStore
    let ethPrice: Subscribable<Double>
    let tokenHolders: [TokenHolder]!

    var coordinators: [Coordinator] = []
    weak var delegate: SendCoordinatorDelegate?
    lazy var sendViewController: SendViewController = {
        return self.makeSendViewController()
    }()

    init(
            transferType: TransferType,
            navigationController: UINavigationController = UINavigationController(),
            session: WalletSession,
            keystore: Keystore,
            storage: TokensDataStore,
            account: Account,
            ethPrice: Subscribable<Double>,
            tokenHolders: [TokenHolder] = []
    ) {
        self.transferType = transferType
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.account = account
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.tokenHolders = tokenHolders
    }

    func start() {
        let symbol = sendViewController.transferType.symbol(server: session.config.server)
        sendViewController.configure(viewModel:
                .init(transferType: sendViewController.transferType,
                        session: session,
                        storage: sendViewController.storage
                        )
        )
        //Make sure the pop up, especially the height, is enough to fit the content in iPad
        sendViewController.preferredContentSize = CGSize(width: 540, height: 700)
        if navigationController.viewControllers.isEmpty {
            navigationController.viewControllers = [sendViewController]
        } else {
            navigationController.pushViewController(sendViewController, animated: true)
        }
    }

    func makeSendViewController() -> SendViewController {
        let controller = SendViewController(
            session: session,
            storage: storage,
            account: account,
            transferType: transferType,
            ethPrice: ethPrice
        )

        if navigationController.viewControllers.isEmpty {
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        }
        switch transferType {
        case .ether(_, let destination):
            controller.targetAddressTextField.value = destination?.description ?? ""
        case .ERC20Token: break
        case .ERC875Token: break
        case .ERC875TokenOrder: break
        case .ERC721Token: break
        case .dapp: break
        }
        controller.delegate = self
        return controller
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}

extension SendCoordinator: SendViewControllerDelegate {
    func didPressConfirm(transaction: UnconfirmedTransaction, transferType: TransferType, in viewController: SendViewController) {

        let configurator = TransactionConfigurator(
            session: session,
            account: account,
            transaction: transaction
        )
        let controller = ConfirmPaymentViewController(
            session: session,
            keystore: keystore,
            configurator: configurator,
            confirmType: .signThenSend
        )
        controller.didCompleted = { result in
            switch result {
            case .success(let type):
                self.delegate?.didFinish(type, in: self)
            case .failure(let error):
                self.navigationController.displayError(error: error)
            }
        }
        navigationController.pushViewController(controller, animated: true)
    }
}
