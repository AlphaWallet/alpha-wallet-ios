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
            case let vc as TokenInstanceViewController2:
                let updatedTokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: session.account)
                if let selection = vc.isMatchingTokenHolder(fromTokenHolders: updatedTokenHolders) {
                    let viewModel: TokenInstanceViewModel2 = .init(tokenId: selection.tokenId, token: token, tokenHolder: selection.tokenHolder, assetDefinitionStore: assetDefinitionStore)
                    vc.configure(viewModel: viewModel)
                }
            case let vc as TokenInstanceActionViewController:
                //TODO it reloads, but doesn't live-reload the changes because the action contains the HTML and it doesn't change
//                vc.configure()
                break
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


//    private func showChooseTokensCardTransferModeViewController(token: TokenObject,
//                                                                for tokenHolder: TokenHolder,
//                                                                in viewController: TransferTokensCardQuantitySelectionViewController) {
//        let vc = makeChooseTokenCardTransferModeViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
//
//    private func showSaleConfirmationScreen(for tokenHolder: TokenHolder,
//                                            linkExpiryDate: Date,
//                                            ethCost: Ether,
//                                            in viewController: SetSellTokensCardExpiryDateViewController) {
//        let vc = makeGenerateSellMagicLinkViewController(paymentFlow: viewController.paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, linkExpiryDate: linkExpiryDate)
//        viewController.navigationController?.present(vc, animated: true)
//    }
//
    private func showTransferConfirmationScreen(for tokenHolder: TokenHolder,
                                                linkExpiryDate: Date,
                                                in viewController: SetTransferTokensCardExpiryDateViewController) {
        let vc = makeGenerateTransferMagicLinkViewController(paymentFlow: viewController.paymentFlow, tokenHolder: tokenHolder, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }
//
//    private func makeGenerateSellMagicLinkViewController(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, ethCost: Ether, linkExpiryDate: Date) -> GenerateSellMagicLinkViewController {
//        let vc = GenerateSellMagicLinkViewController(
//                paymentFlow: paymentFlow,
//                tokenHolder: tokenHolder,
//                ethCost: ethCost,
//                linkExpiryDate: linkExpiryDate
//        )
//        vc.delegate = self
//        vc.configure(viewModel: .init(
//                tokenHolder: tokenHolder,
//                ethCost: ethCost,
//                linkExpiryDate: linkExpiryDate,
//                server: session.server,
//                assetDefinitionStore: assetDefinitionStore
//        ))
//        vc.modalPresentationStyle = .overCurrentContext
//        return vc
//    }
//
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
//
//    private func showEnterSellTokensCardExpiryDateViewController(
//            token: TokenObject,
//            for tokenHolder: TokenHolder,
//            ethCost: Ether,
//            in viewController: EnterSellTokensCardPriceQuantityViewController) {
//        let vc = makeEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, paymentFlow: viewController.paymentFlow)
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//
//    }
//
//    private func showEnterQuantityViewControllerForRedeem(token: TokenObject, for tokenHolder: TokenHolder, in viewController: UIViewController) {
//        let quantityViewController = makeRedeemTokensCardQuantitySelectionViewController(token: token, for: tokenHolder)
//        quantityViewController.navigationItem.largeTitleDisplayMode = .never
//        navigationController.pushViewController(quantityViewController, animated: true)
//    }

//    private func showEnterQuantityViewControllerForTransfer(token: TokenObject, for tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: UIViewController) {
//        let vc = makeTransferTokensCardQuantitySelectionViewController(token: token, for: tokenHolder, paymentFlow: paymentFlow)
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
//
//    private func showEnterPriceQuantityViewController(tokenHolder: TokenHolder,
//                                                      forPaymentFlow paymentFlow: PaymentFlow,
//                                                      in viewController: UIViewController) {
//        let vc = makeEnterSellTokensCardPriceQuantityViewController(token: token, for: tokenHolder, paymentFlow: paymentFlow)
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
//
//    private func showTokenCardRedemptionViewController(token: TokenObject,
//                                                       for tokenHolder: TokenHolder,
//                                                       in viewController: UIViewController) {
//        let quantityViewController = makeTokenCardRedemptionViewController(token: token, for: tokenHolder)
//        quantityViewController.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
//    }
//
//    private func makeRedeemTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> RedeemTokenCardQuantitySelectionViewController {
//        let viewModel = RedeemTokenCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
//        let controller = RedeemTokenCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
//        controller.configure()
////        controller.delegate = self
//        return controller
//    }
//
//    private func makeEnterSellTokensCardPriceQuantityViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensCardPriceQuantityViewController {
//        let viewModel = EnterSellTokensCardPriceQuantityViewControllerViewModel(token: token, tokenHolder: tokenHolder, server: session.server, assetDefinitionStore: assetDefinitionStore)
//        let controller = EnterSellTokensCardPriceQuantityViewController(analyticsCoordinator: analyticsCoordinator, storage: tokensStorage, paymentFlow: paymentFlow, cryptoPrice: ethPrice, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
//        controller.configure()
//        controller.delegate = self
//        return controller
//    }
//
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
//
//    private func makeEnterSellTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, ethCost: Ether, paymentFlow: PaymentFlow) -> SetSellTokensCardExpiryDateViewController {
//        let viewModel = SetSellTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, ethCost: ethCost, server: session.server, assetDefinitionStore: assetDefinitionStore)
//        let controller = SetSellTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, storage: tokensStorage, paymentFlow: paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
//        controller.configure()
//        controller.delegate = self
//        return controller
//    }
//
//    private func makeTokenCardRedemptionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> TokenCardRedemptionViewController {
//        let viewModel = TokenCardRedemptionViewModel(token: token, tokenHolder: tokenHolder)
//        let controller = TokenCardRedemptionViewController(session: session, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
//        controller.configure()
//        controller.delegate = self
//        return controller
//    }
//
//    private func makeTransferTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardQuantitySelectionViewController {
//        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
//        let controller = TransferTokensCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, paymentFlow: paymentFlow, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
//        controller.configure()
//        controller.delegate = self
//        return controller
//    }

//    private func makeChooseTokenCardTransferModeViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenCardTransferModeViewController {
//        let viewModel = ChooseTokenCardTransferModeViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
//        let controller = ChooseTokenCardTransferModeViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
//        controller.configure()
//        controller.delegate = self
//        return controller
//    }

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
//
//    //note that the price must be in szabo for a sell link, price must be rounded
//    private func generateSellLink(tokenHolder: TokenHolder,
//                                  linkExpiryDate: Date,
//                                  ethCost: Ether,
//                                  server: RPCServer) -> String {
//        let ethCostRoundedTo5dp = String(format: "%.5f", Float(string: String(ethCost))!)
//        let cost = Decimal(string: ethCostRoundedTo5dp)! * Decimal(string: "1000000000000000000")!
//        let wei = BigUInt(cost.description)!
//        let order = Order(
//                price: wei,
//                indices: tokenHolder.indices,
//                expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
//                contractAddress: tokenHolder.contractAddress,
//                count: BigUInt(tokenHolder.indices.count),
//                nonce: BigUInt(0),
//                tokenIds: tokenHolder.tokenIds,
//                spawnable: false,
//                nativeCurrencyDrop: false
//        )
//        let orders = [order]
//        let address = keystore.currentWallet.address
//        let etherKeystore = try! EtherKeystore(analyticsCoordinator: analyticsCoordinator)
//        let signedOrders = try! OrderHandler(keystore: etherKeystore).signOrders(orders: orders, account: address, tokenType: tokenHolder.tokenType)
//        return UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrders[0], tokenType: tokenHolder.tokenType)
//    }
//
//    private func sellViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
//        let server: RPCServer
//        switch paymentFlow {
//        case .send(let transactionType):
//            server = transactionType.server
//        case .request:
//            return
//        }
//        let url = generateSellLink(
//            tokenHolder: tokenHolder,
//            linkExpiryDate: linkExpiryDate,
//            ethCost: ethCost,
//            server: server
//        )
//        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//        vc.popoverPresentationController?.sourceView = sender
//        vc.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
//            guard let strongSelf = self else { return }
//            //Be annoying if user copies and we close the sell process
//            if completed && activityType != UIActivity.ActivityType.copyToPasteboard {
//                strongSelf.navigationController.dismiss(animated: false) {
//                    strongSelf.delegate?.didCancel(in: strongSelf)
//                }
//            }
//        }
//        viewController.present(vc, animated: true)
//    }
//
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
//
//    private func showViewRedemptionInfo(in viewController: UIViewController) {
//        let controller = TokenCardRedemptionInfoViewController(delegate: self)
//        controller.navigationItem.largeTitleDisplayMode = .never
//
//        viewController.navigationController?.pushViewController(controller, animated: true)
//    }
//
//    private func showViewEthereumInfo(in viewController: UIViewController) {
//        let controller = WhatIsEthereumInfoViewController(delegate: self)
//        controller.navigationItem.largeTitleDisplayMode = .never
//
//        viewController.navigationController?.pushViewController(controller, animated: true)
//    }
//
    private func makeTokenInstanceViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode) -> TokenInstanceViewController2 {
        let vc = TokenInstanceViewController2(analyticsCoordinator: analyticsCoordinator, tokenObject: token, tokenHolder: tokenHolder, tokenId: tokenId, account: session.account, assetDefinitionStore: assetDefinitionStore, mode: mode)
        vc.delegate = self
        vc.configure()
        vc.navigationItem.largeTitleDisplayMode = .never

        return vc
    }
//
//    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: UIViewController) {
//        let vc = TokenInstanceActionViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: token, tokenHolder: tokenHolder, tokensStorage: tokensStorage, assetDefinitionStore: assetDefinitionStore, action: action, session: session, keystore: keystore)
//        vc.delegate = self
//        vc.configure()
//        vc.navigationItem.largeTitleDisplayMode = .never
//
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
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
        print("didTap(transaction")
    }

    func didTap(activity: Activity, in viewController: TokensCardCollectionViewController) {
        print("didTap(activity")
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
        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: filteredTokenHolders, paymentFlow: .send(type: .ERC875Token(tokenObject)))
        //            transferTokensViewController = vc
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)

    }

    func didFinish(in coordinator: TokenCardSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

//extension ERC1155TokensCardCoordinator: TokensCardViewControllerDelegate {
//    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokensCardViewController) {
//        showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
//    }
//
//    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokensCardViewController) {
//        showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
//    }
//
//    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, for type: PaymentFlow, tokenHolders: [TokenHolder], in viewController: TokensCardViewController) {
//        switch token.type {
//        case .erc721:
//            let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: tokenHolder, paymentFlow: type)
//            transferTokensViewController = vc
//            vc.navigationItem.largeTitleDisplayMode = .never
//            viewController.navigationController?.pushViewController(vc, animated: true)
//        case .erc875, .erc721ForTickets:
//            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: type, in: viewController)
//        case .nativeCryptocurrency, .erc20:
//            break
//        }
//    }
//
//    func didCancel(in viewController: TokensCardViewController) {
//        delegate?.didCancel(in: self)
//    }
//
//    func didPressViewRedemptionInfo(in viewController: TokensCardViewController) {
//        showViewRedemptionInfo(in: viewController)
//    }
//
//    func didTapURL(url: URL, in viewController: TokensCardViewController) {
//        let controller = SFSafariViewController(url: url)
//        controller.makePresentationFullScreenForiOS13Migration()
//        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
//        viewController.present(controller, animated: true)
//    }
//
//    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: TokensCardViewController) {
//        showTokenInstanceViewController(tokenHolder: tokenHolder, in: viewController)
//    }
//
//    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardViewController) {
//        switch action.type {
//        case .tokenScript:
//            showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
//        case .erc20Send, .erc20Receive, .nftRedeem, .nftSell, .nonFungibleTransfer, .swap, .xDaiBridge, .buy:
//            //Couldn't have reached here
//            break
//        }
//    }
//}
//
extension TokensCardCollectionCoordinator: TokenInstanceViewControllerDelegate2 {

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController2) {
        //showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController2) {
        //showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController2) {
//        switch token.type {
//        case .erc721:
            let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: [tokenHolder], paymentFlow: paymentFlow)
//            transferTokensViewController = vc
            vc.navigationItem.largeTitleDisplayMode = .never
            navigationController.pushViewController(vc, animated: true)
//        case .erc875, .erc721ForTickets:
//            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
//        case .nativeCryptocurrency, .erc20:
//            break
//        }
    }

    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController2) {
        //showViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: TokenInstanceViewController2) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController2) {
        //showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
    }
}

//extension ERC1155TokensCardCoordinator: RedeemTokenCardQuantitySelectionViewControllerDelegate {
//    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController) {
//        showTokenCardRedemptionViewController(token: token, for: tokenHolder, in: viewController)
//    }
//
//    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
//        showViewRedemptionInfo(in: viewController)
//    }
//}
//

//extension TokensCardCollectionCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {
//    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController) {
//        showChooseTokensCardTransferModeViewController(token: token, for: tokenHolder, in: viewController)
//    }
//
//    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
//        //showViewRedemptionInfo(in: viewController)
//    }
//}

//
//extension ERC1155TokensCardCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {
//    func didEnterSellTokensPriceQuantity(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController) {
//        showEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, in: viewController)
//    }
//
//    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
//        showViewEthereumInfo(in: viewController)
//    }
//}
//
//extension ERC1155TokensCardCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {
//    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, in viewController: SetSellTokensCardExpiryDateViewController) {
//        showSaleConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
//    }
//
//    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController) {
//        showViewEthereumInfo(in: viewController)
//    }
//}

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

//extension ERC1155TokensCardCoordinator: GenerateSellMagicLinkViewControllerDelegate {
//    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
//        sellViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
//    }
//
//    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
//        viewController.dismiss(animated: true)
//    }
//}
//
//extension TokensCardCollectionCoordinator: ChooseTokenCardTransferModeViewControllerDelegate {
//    func didChooseTransferViaMagicLink(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
//        let vc = makeEnterTransferTokensCardExpiryDateViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
//
//    func didChooseTransferNow(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
//        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: [tokenHolder], paymentFlow: viewController.paymentFlow)
////        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
////        transferTokensViewController = vc
//        vc.navigationItem.largeTitleDisplayMode = .never
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
//
//    func didPressViewInfo(in viewController: ChooseTokenCardTransferModeViewController) {
//        //showViewRedemptionInfo(in: viewController)
//    }
//}

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
//
//extension ERC1155TokensCardCoordinator: TokenCardRedemptionViewControllerDelegate {
//}
//
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
//
//extension ERC1155TokensCardCoordinator: StaticHTMLViewControllerDelegate {
//}
//
//extension ERC1155TokensCardCoordinator: TokenInstanceActionViewControllerDelegate {
//    func confirmTransactionSelected(in viewController: TokenInstanceActionViewController, tokenObject: TokenObject, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
//        switch transactionFunction.makeUnConfirmedTransaction(withTokenObject: tokenObject, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, session: session) {
//        case .success((let transaction, let functionCallMetaData)):
//            let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: .tokenScriptTransaction(confirmType: .signThenSend, contract: contract, keystore: keystore, functionCallMetaData: functionCallMetaData, ethPrice: ethPrice), analyticsCoordinator: analyticsCoordinator)
//            coordinator.delegate = self
//            addCoordinator(coordinator)
//            coordinator.start(fromSource: .tokenScript)
//        case .failure:
//            //TODO throw an error
//            break
//        }
//    }
//
//    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController) {
//        showViewRedemptionInfo(in: viewController)
//    }
//
//    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController) {
//        viewController.navigationController?.popViewController(animated: true)
//    }
//}

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

