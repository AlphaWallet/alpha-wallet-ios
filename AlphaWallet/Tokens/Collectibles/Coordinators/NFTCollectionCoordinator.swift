//  NFTCollectionCoordinator.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/27/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import SafariServices
import MessageUI
import BigInt
import Combine
import AlphaWalletFoundation

protocol NFTCollectionCoordinatorDelegate: AnyObject, CanOpenURL {
    func didClose(in coordinator: NFTCollectionCoordinator)
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: NFTCollectionCoordinator)
    func didTap(transaction: TransactionInstance, in coordinator: NFTCollectionCoordinator)
    func didTap(activity: Activity, in coordinator: NFTCollectionCoordinator)
}

class NFTCollectionCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: Token
    private let session: WalletSession
    private let sessions: ServerDictionary<WalletSession>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let nftProvider: NFTProvider
    private let activitiesService: ActivitiesServiceType
    private var cancelable = Set<AnyCancellable>()
    private let tokensService: TokenViewModelState & TokenHolderState
    private lazy var tokenCardViewFactory: TokenCardViewFactory = {
        TokenCardViewFactory(token: token, assetDefinitionStore: assetDefinitionStore, wallet: session.account)
    }()
    private let currencyService: CurrencyService

    weak var delegate: NFTCollectionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    lazy var rootViewController: NFTCollectionViewController = {
        let viewModel = NFTCollectionViewModel(
            token: token,
            wallet: session.account,
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokensService,
            activitiesService: activitiesService,
            nftProvider: nftProvider,
            config: session.config)

        let controller = NFTCollectionViewController(
            keystore: keystore,
            session: session,
            assetDefinition: assetDefinitionStore,
            analytics: analytics,
            viewModel: viewModel,
            sessions: sessions,
            tokenCardViewFactory: tokenCardViewFactory)
        
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self

        return controller
    }()

    init(session: WalletSession,
         navigationController: UINavigationController,
         keystore: Keystore,
         token: Token,
         assetDefinitionStore: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         nftProvider: NFTProvider,
         activitiesService: ActivitiesServiceType,
         tokensService: TokenViewModelState & TokenHolderState,
         sessions: ServerDictionary<WalletSession>,
         currencyService: CurrencyService) {
        self.currencyService = currencyService
        self.sessions = sessions
        self.tokensService = tokensService
        self.activitiesService = activitiesService
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.nftProvider = nftProvider
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func didClose(in viewController: NFTCollectionViewController) {
        delegate?.didClose(in: self)
    }

    private func showChooseTokensCardTransferModeViewController(token: Token,
                                                                for tokenHolder: TokenHolder,
                                                                in viewController: TransferTokensCardQuantitySelectionViewController) {
        let vc = makeChooseTokenCardTransferModeViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showSaleConfirmationScreen(for tokenHolder: TokenHolder,
                                            linkExpiryDate: Date,
                                            ethCost: Double,
                                            in viewController: SetSellTokensCardExpiryDateViewController) {
        let vc = makeGenerateSellMagicLinkViewController(paymentFlow: viewController.paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func showTransferConfirmationScreen(for tokenHolder: TokenHolder,
                                                linkExpiryDate: Date,
                                                in viewController: SetTransferTokensCardExpiryDateViewController) {
        let vc = makeGenerateTransferMagicLinkViewController(paymentFlow: viewController.paymentFlow, tokenHolder: tokenHolder, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func makeGenerateSellMagicLinkViewController(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, ethCost: Double, linkExpiryDate: Date) -> GenerateSellMagicLinkViewController {
        let vc = GenerateSellMagicLinkViewController(
            paymentFlow: paymentFlow,
            tokenHolder: tokenHolder,
            ethCost: ethCost,
            linkExpiryDate: linkExpiryDate)
        vc.delegate = self
        vc.configure(viewModel: .init(
            tokenHolder: tokenHolder,
            ethCost: ethCost,
            linkExpiryDate: linkExpiryDate,
            server: session.server,
            assetDefinitionStore: assetDefinitionStore
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
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

    private func showEnterSellTokensCardExpiryDateViewController(
            token: Token,
            for tokenHolder: TokenHolder,
            ethCost: Double,
            in viewController: EnterSellTokensCardPriceQuantityViewController) {
        let vc = makeEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showEnterQuantityViewControllerForRedeem(token: Token, for tokenHolder: TokenHolder, in viewController: UIViewController) {
        let quantityViewController = makeRedeemTokensCardQuantitySelectionViewController(token: token, for: tokenHolder)
        quantityViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(quantityViewController, animated: true)
    }

    private func showEnterQuantityViewControllerForTransfer(token: Token, for tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: UIViewController) {
        let vc = makeTransferTokensCardQuantitySelectionViewController(token: token, for: tokenHolder, paymentFlow: paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showEnterPriceQuantityViewController(tokenHolder: TokenHolder,
                                                      forPaymentFlow paymentFlow: PaymentFlow,
                                                      in viewController: UIViewController) {
        let vc = makeEnterSellTokensCardPriceQuantityViewController(token: token, for: tokenHolder, paymentFlow: paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showTokenCardRedemptionViewController(token: Token,
                                                       for tokenHolder: TokenHolder,
                                                       in viewController: UIViewController) {
        let quantityViewController = makeTokenCardRedemptionViewController(token: token, for: tokenHolder)
        quantityViewController.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTokensCardQuantitySelectionViewController(token: Token, for tokenHolder: TokenHolder) -> RedeemTokenCardQuantitySelectionViewController {
        let viewModel = RedeemTokenCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = RedeemTokenCardQuantitySelectionViewController(analytics: analytics, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardPriceQuantityViewController(token: Token, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensCardPriceQuantityViewController {
        let viewModel = EnterSellTokensCardPriceQuantityViewModel(token: token, tokenHolder: tokenHolder, server: session.server, assetDefinitionStore: assetDefinitionStore, currencyService: currencyService)
        let controller = EnterSellTokensCardPriceQuantityViewController(analytics: analytics, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, walletSession: session, keystore: keystore, service: tokensService, currencyService: currencyService)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTokensCardExpiryDateViewController(token: Token, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensCardExpiryDateViewController {
        let viewModel = SetTransferTokensCardExpiryDateViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = SetTransferTokensCardExpiryDateViewController(analytics: analytics, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardExpiryDateViewController(token: Token, for tokenHolder: TokenHolder, ethCost: Double, paymentFlow: PaymentFlow) -> SetSellTokensCardExpiryDateViewController {
        let viewModel = SetSellTokensCardExpiryDateViewModel(token: token, tokenHolder: tokenHolder, ethCost: ethCost, server: session.server, assetDefinitionStore: assetDefinitionStore)
        let controller = SetSellTokensCardExpiryDateViewController(analytics: analytics, paymentFlow: paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTokenCardRedemptionViewController(token: Token, for tokenHolder: TokenHolder) -> TokenCardRedemptionViewController {
        let viewModel = TokenCardRedemptionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TokenCardRedemptionViewController(session: session, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, analytics: analytics, keystore: keystore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardQuantitySelectionViewController(token: Token, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardQuantitySelectionViewController {
        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokensCardQuantitySelectionViewController(analytics: analytics, paymentFlow: paymentFlow, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeChooseTokenCardTransferModeViewController(token: Token, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenCardTransferModeViewController {
        let viewModel = ChooseTokenCardTransferModeViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = ChooseTokenCardTransferModeViewController(analytics: analytics, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func generateTransferLink(tokenHolder: TokenHolder, linkExpiryDate: Date, server: RPCServer) throws -> String {
        let order = Order(
            price: BigUInt(0),
            indices: tokenHolder.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: tokenHolder.contractAddress,
            count: BigUInt(tokenHolder.indices.count),
            nonce: BigUInt(0),
            tokenIds: tokenHolder.tokenIds,
            spawnable: false,
            nativeCurrencyDrop: false)

        let signedOrders = try OrderHandler(keystore: keystore, prompt: R.string.localizable.keystoreAccessKeySign()).signOrders(
            orders: [order],
            account: session.account.address,
            tokenType: tokenHolder.tokenType)

        return UniversalLinkHandler(server: server).createUniversalLink(
            signedOrder: signedOrders[0],
            tokenType: tokenHolder.tokenType)
    }

    //note that the price must be in szabo for a sell link, price must be rounded
    private func generateSellLink(tokenHolder: TokenHolder,
                                  linkExpiryDate: Date,
                                  ethCost: Double,
                                  server: RPCServer) throws -> String {

        let ethCostRoundedTo5dp = String(format: "%.5f", Float(String(ethCost))!)
        let cost = Decimal(string: ethCostRoundedTo5dp)! * Decimal(string: "1000000000000000000")!
        let wei = BigUInt(cost.description)!

        let order = Order(
            price: wei,
            indices: tokenHolder.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: tokenHolder.contractAddress,
            count: BigUInt(tokenHolder.indices.count),
            nonce: BigUInt(0),
            tokenIds: tokenHolder.tokenIds,
            spawnable: false,
            nativeCurrencyDrop: false)

        let signedOrders = try OrderHandler(keystore: keystore, prompt: R.string.localizable.keystoreAccessKeySign()).signOrders(
            orders: [order],
            account: session.account.address,
            tokenType: tokenHolder.tokenType)

        return UniversalLinkHandler(server: server).createUniversalLink(
            signedOrder: signedOrders[0],
            tokenType: tokenHolder.tokenType)
    }

    private func sellViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Double, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        do {
            guard case .send(let transactionType) = paymentFlow else { return }

            let url = try generateSellLink(
                tokenHolder: tokenHolder,
                linkExpiryDate: linkExpiryDate,
                ethCost: ethCost,
                server: transactionType.server)

            displayShareUrlView(url: url, from: viewController, sender: sender)
        } catch {
            viewController.displayError(error: error)
        }
    }

    private func transferViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        do {
            guard case .send(let transactionType) = paymentFlow else { return }

            let url = try generateTransferLink(
                tokenHolder: tokenHolder,
                linkExpiryDate: linkExpiryDate,
                server: transactionType.server)

            displayShareUrlView(url: url, from: viewController, sender: sender)
        } catch {
            viewController.displayError(error: error)
        }
    }

    private func displayShareUrlView(url: String, from viewController: UIViewController, sender: UIView) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { [weak self] activityType, completed, _, _ in
            guard let strongSelf = self else { return }
            //Be annoying if user copies and we close the transfer process
            if completed && activityType != UIActivity.ActivityType.copyToPasteboard {
                strongSelf.navigationController.dismiss(animated: false) {
                    strongSelf.delegate?.didClose(in: strongSelf)
                }
            }
        }

        viewController.present(vc, animated: true)
    }

    private func showViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }

    private func showViewEthereumInfo(in viewController: UIViewController) {
        let controller = WhatIsEthereumInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTCollectionViewControllerDelegate {

    func didSelectAssetSelection(in viewController: NFTCollectionViewController) {
        showTokenCardSelection(tokenHolders: viewController.viewModel.tokenHolders.value)
    }

    func didTap(transaction: TransactionInstance, in viewController: NFTCollectionViewController) {
        delegate?.didTap(transaction: transaction, in: self)
    }

    func didTap(activity: Activity, in viewController: NFTCollectionViewController) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        showNftAsset(tokenHolder: tokenHolder, navigationController: viewController.navigationController)
    }

    func showNftAsset(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive) {
        showNftAsset(tokenHolder: tokenHolder, mode: mode, navigationController: navigationController)
    }

    private func showNftAsset(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive, navigationController: UINavigationController?) {
        let vc: UIViewController
        switch tokenHolder.type {
        case .collectible:
            vc = createNFTAssetListViewController(tokenHolder: tokenHolder)
        case .single:
            vc = createNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: mode)
        }

        navigationController?.pushViewController(vc, animated: true)
    }

    private func createNFTAssetListViewController(tokenHolder: TokenHolder) -> NFTAssetListViewController {
        let viewModel = NFTAssetListViewModel(tokenHolder: tokenHolder)
        let viewController = NFTAssetListViewController(viewModel: viewModel, tokenCardViewFactory: tokenCardViewFactory)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        return viewController
    }

    private func createNFTAssetViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode = .interactive) -> UIViewController {
        let viewModel = NFTAssetViewModel(tokenId: tokenId, token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore, mode: mode, nftProvider: nftProvider, session: session, service: tokensService)
        let viewController = NFTAssetViewController(viewModel: viewModel, tokenCardViewFactory: tokenCardViewFactory)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never

        return viewController
    }

    func didPressViewRedemptionInfo(in viewController: NFTCollectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: NFTCollectionViewController) {
        let controller = SFSafariViewController(url: url)
        controller.makePresentationFullScreenForiOS13Migration()
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true)
    }

    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: NFTCollectionViewController) {
        let vc = createNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTAssetListViewControllerDelegate {

    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenHolder: AlphaWalletFoundation.TokenHolder, tokenId: AlphaWalletFoundation.TokenId) {
        let vc = createNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenId)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTAssetSelectionCoordinatorDelegate {

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let coordinator = NFTAssetSelectionCoordinator(navigationController: navigationController, token: token, tokenHolders: tokenHolders, tokenCardViewFactory: tokenCardViewFactory)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func didTapSend(in coordinator: NFTAssetSelectionCoordinator, token: Token, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)

        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        guard let vc = navigationController.visibleViewController else { return }
        let transactionType: TransactionType = .init(nonFungibleToken: token, tokenHolders: filteredTokenHolders)
        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: vc, in: self)
    }

    func didFinish(in coordinator: NFTAssetSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension NFTCollectionCoordinator: NonFungibleTokenViewControllerDelegate {

    func didPressTransfer(token: Token, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: NFTAssetViewController) {
        switch token.type {
        case .erc721:
            delegate?.didPress(for: paymentFlow, inViewController: viewController, in: self)
        case .erc875, .erc721ForTickets:
            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
        case .nativeCryptocurrency, .erc20:
            assertImpossibleCodePath()
        case .erc1155:
            let transactionType: TransactionType = .init(nonFungibleToken: token, tokenHolders: [tokenHolder])
            delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: viewController, in: self)
        }
    }

    func didTapURL(url: URL, in viewController: NFTAssetViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: NFTAssetViewController) {
        delegate?.didPress(for: .send(type: .tokenScript(action: action, token: token, tokenHolder: tokenHolder)), inViewController: viewController, in: self)
    }

    func didPressRedeem(token: Token, tokenHolder: TokenHolder, in viewController: NFTAssetViewController) {
        showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: NFTAssetViewController) {
        showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: RedeemTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: Token, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showTokenCardRedemptionViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: Token, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController) {
        showChooseTokensCardTransferModeViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {
    func didEnterSellTokensPriceQuantity(token: Token, tokenHolder: TokenHolder, ethCost: Double, in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {
    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Double, in viewController: SetSellTokensCardExpiryDateViewController) {
        showSaleConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: GenerateSellMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
        sellViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension NFTCollectionCoordinator: ChooseTokenCardTransferModeViewControllerDelegate {
    func didChooseTransferViaMagicLink(token: Token, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let vc = makeEnterTransferTokensCardExpiryDateViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(token: Token, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let transactionType: TransactionType = .init(nonFungibleToken: token, tokenHolders: [tokenHolder])
        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: viewController, in: self)
    }

    func didPressViewInfo(in viewController: ChooseTokenCardTransferModeViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: SetTransferTokensCardExpiryDateViewControllerDelegate {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController) {
        showTransferConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        transferViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension NFTCollectionCoordinator: TokenCardRedemptionViewControllerDelegate {
}

extension NFTCollectionCoordinator: CanOpenURL {
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

extension NFTCollectionCoordinator: StaticHTMLViewControllerDelegate {
}

extension Collection where Element == TokenHolder {
    var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] {
        var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] = [:]
        for each in self {
            valuesAll.merge(each.valuesAll) { (current, _) in current }
        }
        return valuesAll
    }
}
