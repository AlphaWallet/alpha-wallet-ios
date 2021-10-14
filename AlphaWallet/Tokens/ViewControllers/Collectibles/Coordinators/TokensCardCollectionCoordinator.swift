//
//  TokensCardCollectionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import Foundation
import UIKit
import Result
import SafariServices
import MessageUI
import BigInt

protocol TokensCardCollectionCoordinatorDelegate: class, CanOpenURL {
    func didCancel(in coordinator: TokensCardCollectionCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCardCollectionCoordinator)
}

class TokensCardCollectionCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: TokenObject
    private lazy var rootViewController: TokensCardCollectionViewController = {
        return makeTokensCardCollectionViewController()
    }()

    private let session: WalletSession
    private let tokensStorage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
//    private weak var transferTokensViewController: TransferTokensCardViaWalletAddressViewController?
    private let analyticsCoordinator: AnalyticsCoordinator
    private let activitiesService: ActivitiesServiceType
    weak var delegate: TokensCardCollectionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    var isReadOnly = false {
        didSet {
            rootViewController.isReadOnly = isReadOnly
        }
    }

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            token: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: EventsDataStoreProtocol,
            analyticsCoordinator: AnalyticsCoordinator,
            activitiesService: ActivitiesServiceType
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
        self.ethPrice = ethPrice
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        let viewModel = TokensCardCollectionViewControllerViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        rootViewController.configure(viewModel: viewModel)
        navigationController.pushViewController(rootViewController, animated: true)
        refreshUponAssetDefinitionChanges()
        refreshUponEthereumEventChanges()
    }

    func makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC1155(type: PaymentFlow) {
        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            switch token.type {
            case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
                break
            case .erc721, .erc1155:
                //TODO is this check still necessary?
                switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
                case .backedByOpenSea:
                    break
                case .notBackedByOpenSea:
                    isReadOnly = true
                }
            }
        case (.send, .watch):
            isReadOnly = true
        }
    }

    private func refreshUponEthereumEventChanges() {
        eventsDataStore.subscribe { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.refreshScreen(forContract: contract)
        }
    }

    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.refreshScreen(forContract: contract)
        }
        assetDefinitionStore.subscribeToSignatureChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.refreshScreen(forContract: contract)
        }
    }

    private func refreshScreen(forContract contract: AlphaWallet.Address) {
        guard contract.sameContract(as: token.contractAddress) else { return }

        for each in navigationController.viewControllers {
            switch each {
            case let vc as TokensCardCollectionViewController:
                let viewModel = TokensCardCollectionViewControllerViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
                vc.configure(viewModel: viewModel)
            case let vc as Erc1155TokenInstanceViewController:
                let updatedTokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: session.account)
                if let selection = vc.isMatchingTokenHolder(fromTokenHolders: updatedTokenHolders) {
                    let viewModel: Erc1155TokenInstanceViewModel = .init(tokenId: selection.tokenId, token: token, tokenHolder: selection.tokenHolder, assetDefinitionStore: assetDefinitionStore)
                    vc.configure(viewModel: viewModel)
                }
            //case let vc as TokenInstanceActionViewController:
                //TODO it reloads, but doesn't live-reload the changes because the action contains the HTML and it doesn't change
//                vc.configure()
//                break
            default:
                break
            }
        }
    }

    private func makeTokensCardCollectionViewController() -> TokensCardCollectionViewController {
        let viewModel = TokensCardCollectionViewControllerViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        let controller = TokensCardCollectionViewController(session: session, tokensDataStore: tokensStorage, assetDefinition: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, activitiesService: activitiesService, eventsDataStore: eventsDataStore)
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self

        return controller
    }

    func stop() {
        session.stop()
    }

    private func showTransferConfirmationScreen(for tokenHolder: TokenHolder,
                                                linkExpiryDate: Date,
                                                in viewController: SetTransferTokensCardExpiryDateViewController) {
        let vc = makeGenerateTransferMagicLinkViewController(paymentFlow: viewController.paymentFlow, tokenHolder: tokenHolder, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func makeGenerateTransferMagicLinkViewController(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, linkExpiryDate: Date) -> GenerateTransferMagicLinkViewController {
        let vc = GenerateTransferMagicLinkViewController(
                paymentFlow: paymentFlow,
                tokenHolder: tokenHolder,
                linkExpiryDate: linkExpiryDate
        )
        vc.delegate = self
        vc.configure(viewModel: .init(
                tokenHolder: tokenHolder,
                linkExpiryDate: linkExpiryDate,
                assetDefinitionStore: assetDefinitionStore
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }

    private func makeEnterTransferTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensCardExpiryDateViewController {
        let viewModel = SetTransferTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = SetTransferTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardViaWalletAddressViewController(token: TokenObject, for tokenHolders: [TokenHolder], paymentFlow: PaymentFlow) -> TransferTokenBatchCardsViaWalletAddressViewController {
        let viewModel = TransferTokenBatchCardsViaWalletAddressViewControllerViewModel(token: token, tokenHolders: tokenHolders, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokenBatchCardsViaWalletAddressViewController(analyticsCoordinator: analyticsCoordinator, token: token, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self

        return controller
    }

    private func generateTransferLink(tokenHolder: TokenHolder, linkExpiryDate: Date, server: RPCServer) -> String {
        let order = Order(
            price: BigUInt(0),
            indices: tokenHolder.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: tokenHolder.contractAddress,
            count: BigUInt(tokenHolder.indices.count),
            nonce: BigUInt(0),
            tokenIds: tokenHolder.tokenIds,
            spawnable: false,
            nativeCurrencyDrop: false
        )
        let orders = [order]
        let address = keystore.currentWallet.address
        let etherKeystore = try! EtherKeystore(analyticsCoordinator: analyticsCoordinator)
        let signedOrders = try! OrderHandler(keystore: etherKeystore).signOrders(orders: orders, account: address, tokenType: tokenHolder.tokenType)
        return UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrders[0], tokenType: tokenHolder.tokenType)
    }

    private func transferViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let server: RPCServer
        switch paymentFlow {
        case .send(let transactionType):
            server = transactionType.server
        case .request:
            return
        }

        let url = generateTransferLink(tokenHolder: tokenHolder, linkExpiryDate: linkExpiryDate, server: server)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            guard let strongSelf = self else { return }
            //Be annoying if user copies and we close the transfer process
            if completed && activityType != UIActivity.ActivityType.copyToPasteboard {
                strongSelf.navigationController.dismiss(animated: false) {
                    strongSelf.delegate?.didCancel(in: strongSelf)
                }
            }
        }
        viewController.present(vc, animated: true)
    }

    private func makeTokenInstanceViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode) -> Erc1155TokenInstanceViewController {
        let vc = Erc1155TokenInstanceViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: token, tokenHolder: tokenHolder, tokenId: tokenId, account: session.account, assetDefinitionStore: assetDefinitionStore, mode: mode)
        vc.delegate = self
        vc.configure()
        vc.navigationItem.largeTitleDisplayMode = .never

        return vc
    }
}

extension TokensCardCollectionCoordinator: TokensCardCollectionViewControllerDelegate {
    func didSelectTokenHolder(in viewController: TokensCardCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        switch tokenHolder.type {
        case .collectible:
            let viewModel = TokenCardListViewControllerViewModel(tokenHolder: tokenHolder)
            let viewController = TokenCardListViewController(viewModel: viewModel, tokenObject: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
            viewController.delegate = self

            navigationController.pushViewController(viewController, animated: true)
        case .single:
            let viewController = makeTokenInstanceViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: .interactive)

            navigationController.pushViewController(viewController, animated: true)
        }
    }

    func didTap(transaction: TransactionInstance, in viewController: TokensCardCollectionViewController) {
        debug("didTap(transaction")
    }

    func didTap(activity: Activity, in viewController: TokensCardCollectionViewController) {
        debug("didTap(activity")
    }

    func didSelectAssetSelection(in viewController: TokensCardCollectionViewController) {
        showTokenCardSelection(tokenHolders: viewController.viewModel.tokenHolders)
    }

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let coordinator = TokenCardSelectionCoordinator(navigationController: navigationController, tokenObject: token, tokenHolders: tokenHolders, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }
}

extension TokensCardCollectionCoordinator: TokenCardListViewControllerDelegate {
    func selectTokenCardsSelected(in viewController: TokenCardListViewController) {
        showTokenCardSelection(tokenHolders: [viewController.tokenHolder])
    }

    func didSelectTokenCard(in viewController: TokenCardListViewController, tokenId: TokenId) {
        let viewController = makeTokenInstanceViewController(tokenHolder: viewController.tokenHolder, tokenId: tokenId, mode: .interactive)
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension TokensCardCollectionCoordinator: TokenCardSelectionCoordinatorDelegate {
    func didTapSell(in coordinator: TokenCardSelectionCoordinator, tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)
    }

    func didTapDeal(in coordinator: TokenCardSelectionCoordinator, tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)
        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: filteredTokenHolders, paymentFlow: .send(type: .erc875Token(tokenObject)))
        //            transferTokensViewController = vc
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)

    }

    func didFinish(in coordinator: TokenCardSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCardCollectionCoordinator: Erc1155TokenInstanceViewControllerDelegate {

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: Erc1155TokenInstanceViewController) {
        //showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: Erc1155TokenInstanceViewController) {
        //showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: Erc1155TokenInstanceViewController) {
        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: [tokenHolder], paymentFlow: paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)
    }

    func didPressViewRedemptionInfo(in viewController: Erc1155TokenInstanceViewController) {
        //showViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: Erc1155TokenInstanceViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: Erc1155TokenInstanceViewController) {
        //showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
    }
}

extension TokensCardCollectionCoordinator: TransferNFTCoordinatorDelegate {
    func didClose(in coordinator: TransferNFTCoordinator) {
        removeCoordinator(coordinator)
    }

    func didCompleteTransfer(withTransactionConfirmationCoordinator transactionConfirmationCoordinator: TransactionConfirmationCoordinator, result: TransactionConfirmationResult, inCoordinator coordinator: TransferNFTCoordinator) {
        transactionConfirmationCoordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }
}

extension TokensCardCollectionCoordinator: SetTransferTokensCardExpiryDateViewControllerDelegate {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController) {
        showTransferConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController) {
        //showViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCollectionCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        transferViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TokensCardCollectionCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        //transferTokensViewController?.didScanQRCode(result)
    }
}

extension TokensCardCollectionCoordinator: TransferTokenBatchCardsViaWalletAddressViewControllerDelegate {

    func some(tokenHolder: TokenHolder, in viewController: TransferTokenBatchCardsViaWalletAddressViewController) {
        let viewController = makeTokenInstanceViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: .preview)

        navigationController.pushViewController(viewController, animated: true)
    }

    func didEnterWalletAddress(tokenHolders: [TokenHolder], to recipient: AlphaWallet.Address, paymentFlow: PaymentFlow, in viewController: TransferTokenBatchCardsViaWalletAddressViewController) {
        guard let tokenHolder = tokenHolders.first else { return }
        guard let selection = tokenHolder.selections.first else { return }
        let transaction = UnconfirmedTransaction(
                transactionType: .erc1155Token(token),
                value: BigInt(0),
                recipient: recipient,
                contract: tokenHolder.contractAddress,
                data: nil,
                tokenIdsAndValues: [.init(tokenId: selection.tokenId, value: BigUInt(selection.value))]
        )
        let tokenInstanceName = tokenHolder.values["name"]?.stringValue
        let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore, ethPrice: ethPrice, tokenInstanceName: tokenInstanceName)
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .sendNft)
    }

    func didPressViewInfo(in viewController: TransferTokenBatchCardsViaWalletAddressViewController) {

    }

    func openQRCode(in controller: TransferTokenBatchCardsViaWalletAddressViewController) {

    }

    func openQRCode(in controller: TransferTokensCardViaWalletAddressViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .addressTextField)
    }

    func didEnterWalletAddress(tokenHolder: TokenHolder, to recipient: AlphaWallet.Address, paymentFlow: PaymentFlow, in viewController: TransferTokensCardViaWalletAddressViewController) {
        switch session.account.type {
        case .real:
            switch paymentFlow {
            case .send:
                if case .send(let transactionType) = paymentFlow {
                    let coordinator = TransferNFTCoordinator(navigationController: navigationController, transactionType: transactionType, tokenHolder: tokenHolder, recipient: recipient, keystore: keystore, session: session, ethPrice: ethPrice, analyticsCoordinator: analyticsCoordinator)
                    addCoordinator(coordinator)
                    coordinator.delegate = self
                    coordinator.start()
                }
            case .request:
                return
            }
        case .watch:
            break
        }
    }

    func didPressViewInfo(in viewController: TransferTokensCardViaWalletAddressViewController) {
        //showViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCollectionCoordinator: CanOpenURL {
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

extension TokensCardCollectionCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.localizedDescription)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        // no-op
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }
}

extension TokensCardCollectionCoordinator: TransactionInProgressCoordinatorDelegate {
    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)
    }
}

