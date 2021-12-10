import Foundation
import UIKit
import BigInt
import PromiseKit
import Result

protocol SendCoordinatorDelegate: class, CanOpenURL {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: SendCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: SendCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

class SendCoordinator: Coordinator {
    private let transactionType: TransactionType
    private let session: WalletSession
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private var transactionConfirmationResult: ConfirmResult? = .none

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
            ethPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.transactionType = transactionType
        self.navigationController = navigationController
        self.session = session
        self.keystore = keystore
        self.storage = storage
        self.ethPrice = ethPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        sendViewController.configure(viewModel: .init(transactionType: sendViewController.transactionType, session: session, storage: storage))

        navigationController.pushViewController(sendViewController, animated: true)
    }

    private func makeSendViewController() -> SendViewController {
        let controller = SendViewController(
            session: session,
            storage: storage,
            transactionType: transactionType,
            cryptoPrice: ethPrice
        )

        switch transactionType {
        case .nativeCryptocurrency(_, let destination, let amount):
            controller.targetAddressTextField.value = destination?.stringValue ?? ""
            if let amount = amount {
                controller.amountTextField.ethCost = EtherNumberFormatter.full.string(from: amount, units: .ether)
            } else {
                //do nothing, especially not set it to a default BigInt() / 0
            }
        case .erc20Token(_, let destination, let amount):
            controller.targetAddressTextField.value = destination?.stringValue ?? ""
            controller.amountTextField.ethCost = amount ?? ""
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))

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

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .sendFungibleScreen)
    }

    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?) {
        let configuration: TransactionConfirmationConfiguration = .sendFungiblesTransaction(
            confirmType: .signThenSend,
            keystore: keystore,
            assetDefinitionStore: assetDefinitionStore,
            amount: FungiblesTransactionAmount(value: amount, shortValue: shortValue, isAllFunds: viewController.isAllFunds),
            ethPrice: ethPrice
        )
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .sendFungible)
    }

    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void) {
        ContractDataDetector(address: contract, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore).fetch(completion: completion)
    }
}

extension SendCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.prettyError)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.removeCoordinator(coordinator)

            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension SendCoordinator: TransactionInProgressCoordinatorDelegate {

    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        switch transactionConfirmationResult {
        case .some(let result):
            delegate?.didFinish(result, in: self)
        case .none:
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
