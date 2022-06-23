//
//  TransferCollectiblesCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.12.2021.
//

import UIKit
import BigInt
import Result

typealias AWResult = Result

protocol TransferCollectiblesCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransferCollectiblesCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransferCollectiblesCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: TransferCollectiblesCoordinator)
    func didCancel(in coordinator: TransferCollectiblesCoordinator)
}

class TransferCollectiblesCoordinator: Coordinator {
    private lazy var sendViewController: TransferTokenBatchCardsViaWalletAddressViewController = {
        return makeTransferTokensCardViaWalletAddressViewController(token: tokenObject, tokenHolders: filteredTokenHolders)
    }()
    private let keystore: Keystore
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let filteredTokenHolders: [TokenHolder]
    private var transactionConfirmationResult: ConfirmResult? = .none

    weak var delegate: TransferCollectiblesCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            filteredTokenHolders: [TokenHolder],
            tokenObject: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator,
            domainResolutionService: DomainResolutionServiceType
    ) {
        self.filteredTokenHolders = filteredTokenHolders
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        sendViewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        sendViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(sendViewController, animated: true)
    }

    @objc private func dismiss() {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
    }

    private func makeTransferTokensCardViaWalletAddressViewController(token: TokenObject, tokenHolders: [TokenHolder]) -> TransferTokenBatchCardsViaWalletAddressViewController {
        let viewModel = TransferTokenBatchCardsViaWalletAddressViewControllerViewModel(token: token, tokenHolders: tokenHolders)
        let tokenCardViewFactory: TokenCardViewFactory = {
            TokenCardViewFactory(token: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: session.account)
        }()
        let controller = TransferTokenBatchCardsViaWalletAddressViewController(token: token, viewModel: viewModel, tokenCardViewFactory: tokenCardViewFactory, domainResolutionService: domainResolutionService)
        controller.configure()
        controller.delegate = self

        return controller
    }
}

extension TransferCollectiblesCoordinator: TransferTokenBatchCardsViaWalletAddressViewControllerDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func didSelectTokenHolder(tokenHolder: TokenHolder, in viewController: TransferTokenBatchCardsViaWalletAddressViewController) {
        delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: self)
    }

    func didEnterWalletAddress(tokenHolders: [TokenHolder], to recipient: AlphaWallet.Address, in viewController: TransferTokenBatchCardsViaWalletAddressViewController) {
        do {
            //NOTE: we have to make sure that token holders have the same contract address!
            guard let firstTokenHolder = tokenHolders.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

            let tokenIdsAndValues: [UnconfirmedTransaction.TokenIdAndValue] = tokenHolders
                .flatMap { $0.selections }
                .compactMap { .init(tokenId: $0.tokenId, value: BigUInt($0.value)) }

            let tokenInstanceNames = tokenHolders
                .valuesAll
                .compactMapValues { $0.nameStringValue }

            let transaction = UnconfirmedTransaction(
                transactionType: .erc1155Token(tokenObject, transferType: tokenIdsAndValues.erc1155TokenTransactionType, tokenHolders: tokenHolders),
                    value: BigInt(0),
                    recipient: recipient,
                    contract: firstTokenHolder.contractAddress,
                    data: nil,
                    tokenIdsAndValues: tokenIdsAndValues
            )

            let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore, tokenInstanceNames: tokenInstanceNames)
            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start(fromSource: .sendNft)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func openQRCode(in controller: TransferTokenBatchCardsViaWalletAddressViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .addressTextField)
    }
}

extension TransferCollectiblesCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        sendViewController.didScanQRCode(result)
    }
}

extension TransferCollectiblesCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: coordinator)
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TransferCollectiblesCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}
