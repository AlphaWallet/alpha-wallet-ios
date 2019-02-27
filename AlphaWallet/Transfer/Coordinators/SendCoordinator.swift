// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore

protocol SendCoordinatorDelegate: class, CanOpenURL {
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {
    private let transferType: TransferType
    private let session: WalletSession
    private let account: Account
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let tokenHolders: [TokenHolder]!

    lazy var sendViewController: SendViewController = {
        return makeSendViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: SendCoordinatorDelegate?

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
            cryptoPrice: ethPrice
        )

        if navigationController.viewControllers.isEmpty {
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        }
        switch transferType {
        case .nativeCryptocurrency(_, let destination):
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
        controller.didCompleted = { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let type):
                strongSelf.delegate?.didFinish(type, in: strongSelf)
            case .failure(let error):
                strongSelf.navigationController.displayError(error: error)
            }
        }
        navigationController.pushViewController(controller, animated: true)
    }
}

extension SendCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
