// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Result

protocol SendCoordinatorDelegate: class, CanOpenURL {
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {
    private let transactionType: TransactionType
    private let session: WalletSession
    private let account: AlphaWallet.Address
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let tokenHolders: [TokenHolder]!
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator?
    private var transactionConfirmationResult: TransactionConfirmationResult = .noData

    lazy var sendViewController: SendViewController = {
        return makeSendViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: SendCoordinatorDelegate?

    init(
            transactionType: TransactionType,
            navigationController: UINavigationController,
            session: WalletSession,
            keystore: Keystore,
            storage: TokensDataStore,
            account: AlphaWallet.Address,
            ethPrice: Subscribable<Double>,
            tokenHolders: [TokenHolder] = [],
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator?
    ) {
        self.transactionType = transactionType
        self.navigationController = navigationController
        self.session = session
        self.account = account
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.tokenHolders = tokenHolders
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController.setNavigationBarHidden(false, animated: true)
    }

    func start() {
        sendViewController.configure(viewModel:
                .init(transactionType: sendViewController.transactionType,
                        session: session,
                        storage: sendViewController.storage
                        )
        )

        sendViewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        navigationController.pushViewController(sendViewController, animated: true)
    }

    private func makeSendViewController() -> SendViewController {
        let controller = SendViewController(
            session: session,
            storage: storage,
            account: account,
            transactionType: transactionType,
            cryptoPrice: ethPrice,
            assetDefinitionStore: assetDefinitionStore
        )

        switch transactionType {
        case .nativeCryptocurrency(_, let destination, let amount):
            controller.targetAddressTextField.value = destination?.stringValue ?? ""
            if let amount = amount {
                controller.amountTextField.ethCost = EtherNumberFormatter.full.string(from: amount, units: .ether)
            } else {
                //do nothing, especially not set it to a default BigInt() / 0
            }
        case .ERC20Token(_, let destination, let amount):
            controller.targetAddressTextField.value = destination?.stringValue ?? ""
            controller.amountTextField.ethCost = amount ?? ""
        case .ERC875Token: break
        case .ERC875TokenOrder: break
        case .ERC721Token: break
        case .ERC721ForTicketToken: break
        case .dapp: break
        case .tokenScript: break
        case .claimPaidErc875MagicLink: break
        }
        controller.delegate = self
        return controller
    }

    @objc private func dismiss() {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
    }
}

extension SendCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        sendViewController.didScanQRCode(result)
    }
}

extension SendCoordinator: SendViewControllerDelegate {
    func openQRCode(in controller: SendViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(navigationController: navigationController, account: session.account)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String) {
        let configuration: TransactionConfirmationConfiguration = .sendFungiblesTransaction(
            confirmType: .signThenSend,
            keystore: keystore,
            assetDefinitionStore: assetDefinitionStore,
            amount: amount,
            ethPrice: ethPrice
        )
        let coordinator = TransactionConfirmationCoordinator(navigationController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void) {
        fetchContractDataFor(address: contract, storage: storage, assetDefinitionStore: assetDefinitionStore, completion: completion)
    }
}

extension SendCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.prettyError)
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.removeCoordinator(coordinator)

            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(navigationController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SendCoordinator: TransactionInProgressCoordinatorDelegate {

    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        switch transactionConfirmationResult {
        case .confirmationResult(let result):
            delegate?.didFinish(result, in: self)
        case .noData:
            break
        }
    }
}

extension SendCoordinator: CanOpenURL {
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
