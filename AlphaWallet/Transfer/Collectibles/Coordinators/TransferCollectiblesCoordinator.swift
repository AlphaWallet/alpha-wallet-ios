//
//  TransferCollectiblesCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.12.2021.
//

import UIKit
import BigInt
import Result

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
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
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
            tokensStorage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            tokenObject: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.filteredTokenHolders = filteredTokenHolders
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.ethPrice = ethPrice
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
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
        let viewModel = TransferTokenBatchCardsViaWalletAddressViewControllerViewModel(token: token, tokenHolders: tokenHolders, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokenBatchCardsViaWalletAddressViewController(analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
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

        //NOTE: we have to make sure that token holders have the same contract address!
        guard let firstTokenHolder = tokenHolders.first else { return }

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

        let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore, ethPrice: ethPrice, tokenInstanceNames: tokenInstanceNames)
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .sendNft)
    }

    func openQRCode(in controller: TransferTokenBatchCardsViaWalletAddressViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account)
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
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.localizedDescription)
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
    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)
        switch transactionConfirmationResult {
        case .some(let result):
            delegate?.didFinish(result, in: self)
        case .none:
            break
        }
    }
}
