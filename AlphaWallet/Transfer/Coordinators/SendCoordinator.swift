import Foundation
import UIKit
import BigInt
import PromiseKit
import AlphaWalletFoundation

protocol SendCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: SendCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {
    private let transactionType: TransactionType
    private let session: WalletSession
    private let keystore: Keystore
    private let tokensService: TokenProvidable & TokenAddable & TokenViewModelState & TokenBalanceRefreshable
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let importToken: ImportToken

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    lazy var sendViewController: SendViewController = {
        return makeSendViewController()
    }()

    weak var delegate: SendCoordinatorDelegate?

    init(
            transactionType: TransactionType,
            navigationController: UINavigationController,
            session: WalletSession,
            keystore: Keystore,
            tokensService: TokenProvidable & TokenAddable & TokenViewModelState & TokenBalanceRefreshable,
            assetDefinitionStore: AssetDefinitionStore,
            analytics: AnalyticsLogger,
            domainResolutionService: DomainResolutionServiceType,
            importToken: ImportToken
    ) {
        self.importToken = importToken
        self.transactionType = transactionType
        self.navigationController = navigationController
        self.session = session
        self.keystore = keystore
        self.tokensService = tokensService
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        navigationController.pushViewController(sendViewController, animated: true)
    }
    
    private func makeSendViewController() -> SendViewController {
        let viewModel = SendViewModel(transactionType: transactionType, session: session, tokensService: tokensService, importToken: importToken)
        let controller = SendViewController(viewModel: viewModel, domainResolutionService: domainResolutionService)

//        switch transactionType {
//        case .nativeCryptocurrency(_, let destination, let amount):
//            controller.targetAddressTextField.value = destination?.stringValue ?? ""
//            if let amount = amount {
//                controller.amountTextField.set(crypto: EtherNumberFormatter.full.string(from: amount, units: .ether), useFormatting: true)
//            } else {
//                //do nothing, especially not set it to a default BigInt() / 0
//            }
//        case .erc20Token(let token, let destination, let amount):
//            controller.targetAddressTextField.value = destination?.stringValue ?? ""
////            controller.amountTextField.set(crypto: amount ?? "", useFormatting: true)
//            if let amount = amount {
//                controller.amountTextField.set(crypto: "1.2"/*EtherNumberFormatter.full.string(from: amount, decimals: token.decimals)*/, useFormatting: true)
//            } else {
//                //do nothing, especially not set it to a default BigInt() / 0
//            }
//        case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
//            break
//        }
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.hidesBottomBarWhenPushed = true

        return controller
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
    func didClose(in viewController: SendViewController) {
        delegate?.didCancel(in: self)
    }

    func openQRCode(in viewController: SendViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: session.account, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .sendFungibleScreen)
    }

    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?) {
        do {
            let configuration: TransactionType.Configuration = .sendFungiblesTransaction(
                confirmType: .signThenSend,
                amount: FungiblesTransactionAmount(value: amount, shortValue: shortValue, isAllFunds: viewController.amountTextField.viewModel.isAllFunds))

            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokensService)
            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start(fromSource: .sendFungible)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }
}

extension SendCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)
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

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension SendCoordinator: TransactionInProgressCoordinatorDelegate {

    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
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
