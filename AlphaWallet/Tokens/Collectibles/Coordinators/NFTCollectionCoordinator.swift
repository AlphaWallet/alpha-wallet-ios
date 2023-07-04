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
    func didTap(transaction: Transaction, in coordinator: NFTCollectionCoordinator)
    func didTap(activity: Activity, in coordinator: NFTCollectionCoordinator)
}

class NFTCollectionCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: Token
    private let session: WalletSession
    private let sessionsProvider: SessionsProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let nftProvider: NFTProvider
    private let activitiesService: ActivitiesServiceType
    private let tokensService: TokensProcessingPipeline
    private lazy var tokenCardViewFactory: TokenCardViewFactory = {
        TokenCardViewFactory(
            token: token,
            assetDefinitionStore: assetDefinitionStore,
            wallet: session.account,
            tokenImageFetcher: tokenImageFetcher)
    }()
    private let currencyService: CurrencyService
    private let tokenImageFetcher: TokenImageFetcher
    private let tokenActionsProvider: SupportedTokenActionsProvider

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
            config: session.config,
            tokenImageFetcher: tokenImageFetcher)

        let controller = NFTCollectionViewController(
            keystore: keystore,
            session: session,
            assetDefinition: assetDefinitionStore,
            analytics: analytics,
            viewModel: viewModel,
            sessionsProvider: sessionsProvider,
            tokenCardViewFactory: tokenCardViewFactory,
            tokenImageFetcher: tokenImageFetcher)

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
         tokensService: TokensProcessingPipeline,
         sessionsProvider: SessionsProvider,
         currencyService: CurrencyService,
         tokenImageFetcher: TokenImageFetcher,
         tokenActionsProvider: SupportedTokenActionsProvider) {

        self.tokenActionsProvider = tokenActionsProvider
        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.sessionsProvider = sessionsProvider
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

    func didTap(transaction: Transaction, in viewController: NFTCollectionViewController) {
        delegate?.didTap(transaction: transaction, in: self)
    }

    func didTap(activity: Activity, in viewController: NFTCollectionViewController) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        showNftAsset(tokenHolder: tokenHolder, navigationController: viewController.navigationController)
    }

    func showNftAsset(tokenHolder: TokenHolder, mode: NFTAssetViewModel.InterationMode = .interactive) {
        showNftAsset(tokenHolder: tokenHolder, mode: mode, navigationController: navigationController)
    }

    private func showNftAsset(tokenHolder: TokenHolder,
                              mode: NFTAssetViewModel.InterationMode = .interactive,
                              navigationController: UINavigationController?) {

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
        let viewController = NFTAssetListViewController(
            viewModel: viewModel,
            tokenCardViewFactory: tokenCardViewFactory)

        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        return viewController
    }

    private func createNFTAssetViewController(tokenHolder: TokenHolder,
                                              tokenId: TokenId,
                                              mode: NFTAssetViewModel.InterationMode = .interactive) -> UIViewController {

        let viewModel = NFTAssetViewModel(
            tokenId: tokenId,
            token: token,
            tokenHolder: tokenHolder,
            assetDefinitionStore: assetDefinitionStore,
            mode: mode,
            nftProvider: nftProvider,
            session: session,
            service: tokensService,
            tokenActionsProvider: tokenActionsProvider)

        let viewController = NFTAssetViewController(
            viewModel: viewModel,
            tokenCardViewFactory: tokenCardViewFactory)
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

    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenHolder: TokenHolder, tokenId: TokenId) {
        let vc = createNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenId)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTAssetSelectionCoordinatorDelegate {

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let coordinator = NFTAssetSelectionCoordinator(
            navigationController: navigationController,
            token: token,
            tokenHolders: tokenHolders,
            tokenCardViewFactory: tokenCardViewFactory)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func didTapSend(in coordinator: NFTAssetSelectionCoordinator, token: Token, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)
        guard let vc = navigationController.visibleViewController else { return }

        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        let transactionType: TransactionType = .init(nonFungibleToken: token, tokenHolders: filteredTokenHolders)

        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: vc, in: self)
    }

    func didFinish(in coordinator: NFTAssetSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension NFTCollectionCoordinator: NonFungibleTokenViewControllerDelegate {

    func didPressTransfer(token: Token,
                          tokenHolder: TokenHolder,
                          paymentFlow: PaymentFlow,
                          in viewController: NFTAssetViewController) {

        switch token.type {
        case .erc721:
            delegate?.didPress(for: paymentFlow, inViewController: viewController, in: self)
        case .erc875, .erc721ForTickets:
            let viewModel = TransferTokensCardQuantitySelectionViewModel(
                token: token,
                tokenHolder: tokenHolder,
                assetDefinitionStore: assetDefinitionStore,
                session: session)

            let controller = TransferTokensCardQuantitySelectionViewController(
                viewModel: viewModel,
                assetDefinitionStore: assetDefinitionStore)

            controller.configure()
            controller.delegate = self

            controller.navigationItem.largeTitleDisplayMode = .never
            viewController.navigationController?.pushViewController(controller, animated: true)
        case .nativeCryptocurrency, .erc20:
            preconditionFailure("Not expect to transfer fungibles here")
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

    func didTap(action: TokenInstanceAction,
                tokenHolder: TokenHolder,
                viewController: NFTAssetViewController) {

        delegate?.didPress(for: .send(type: .tokenScript(action: action, token: token, tokenHolder: tokenHolder)), inViewController: viewController, in: self)
    }

    func didPressRedeem(token: Token, tokenHolder: TokenHolder, in viewController: NFTAssetViewController) {
        let viewModel = RedeemTokenCardQuantitySelectionViewModel(
            token: token,
            tokenHolder: tokenHolder,
            assetDefinitionStore: assetDefinitionStore,
            session: session)

        let controller = RedeemTokenCardQuantitySelectionViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore)

        controller.configure()
        controller.delegate = self

        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    func didPressSell(tokenHolder: TokenHolder, in viewController: NFTAssetViewController) {
        let viewModel = EnterSellTokensCardPriceQuantityViewModel(
            token: token,
            tokenHolder: tokenHolder,
            session: session,
            assetDefinitionStore: assetDefinitionStore,
            currencyService: currencyService)

        let controller = EnterSellTokensCardPriceQuantityViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore,
            service: tokensService,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        controller.configure()
        controller.delegate = self

        controller.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: RedeemTokenCardQuantitySelectionViewControllerDelegate {

    func didSelectQuantity(token: Token,
                           tokenHolder: TokenHolder,
                           in viewController: RedeemTokenCardQuantitySelectionViewController) {

        let viewModel = TokenCardRedemptionViewModel(
            token: token,
            tokenHolder: tokenHolder,
            session: session,
            keystore: keystore)

        let controller = TokenCardRedemptionViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore)

        controller.configure()
        controller.delegate = self

        controller.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {

    func didSelectQuantity(token: Token,
                           tokenHolder: TokenHolder,
                           in viewController: TransferTokensCardQuantitySelectionViewController) {

        let viewModel = ChooseTokenCardTransferModeViewModel(
            token: token,
            tokenHolder: tokenHolder,
            session: session)

        let controller = ChooseTokenCardTransferModeViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore)

        controller.configure()
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {

    func didEnterSellTokensPriceQuantity(token: Token,
                                         tokenHolder: TokenHolder,
                                         ethCost: Double,
                                         in viewController: EnterSellTokensCardPriceQuantityViewController) {

        let viewModel = SetSellTokensCardExpiryDateViewModel(
            token: token,
            tokenHolder: tokenHolder,
            ethCost: ethCost,
            session: session)

        let controller = SetSellTokensCardExpiryDateViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore,
            session: session)

        controller.configure()
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {

    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder,
                                    linkExpiryDate: Date,
                                    ethCost: Double,
                                    in viewController: SetSellTokensCardExpiryDateViewController) {

        let viewModel = GenerateSellMagicLinkViewModel(
            magicLinkData: MagicLinkGenerator.MagicLinkData(
                tokenIds: tokenHolder.tokenIds,
                indices: tokenHolder.indices,
                tokenType: tokenHolder.tokenType,
                contractAddress: tokenHolder.contractAddress,
                count: tokenHolder.count),
            ethCost: ethCost,
            linkExpiryDate: linkExpiryDate,
            keystore: keystore,
            session: session)

        let vc = GenerateSellMagicLinkViewController(viewModel: viewModel)

        vc.delegate = self
        vc.configure()
        vc.modalPresentationStyle = .overCurrentContext

        viewController.navigationController?.present(vc, animated: true)
    }

    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: GenerateSellMagicLinkViewControllerDelegate {

    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
        Task { @MainActor in
            do {
                let url = try await viewController.viewModel.generateSellLink()
                displayShareUrlView(url: url, from: viewController, sender: sender)
            } catch {
                viewController.displayError(error: error)
            }
        }
    }

    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension NFTCollectionCoordinator: ChooseTokenCardTransferModeViewControllerDelegate {

    func didChooseTransferViaMagicLink(token: Token, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let viewModel = SetTransferTokensCardExpiryDateViewModel(
            token: token,
            tokenHolder: tokenHolder,
            assetDefinitionStore: assetDefinitionStore)

        let controller = SetTransferTokensCardExpiryDateViewController(
            viewModel: viewModel,
            assetDefinitionStore: assetDefinitionStore,
            session: session)

        controller.configure()
        controller.delegate = self

        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
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
        let viewModel = GenerateTransferMagicLinkViewModel(
            magicLinkData: .init(
                tokenIds: tokenHolder.tokenIds,
                indices: tokenHolder.indices,
                tokenType: tokenHolder.tokenType,
                contractAddress: tokenHolder.contractAddress,
                count: tokenHolder.count),
            linkExpiryDate: linkExpiryDate,
            assetDefinitionStore: assetDefinitionStore,
            keystore: keystore,
            session: session)

        let vc = GenerateTransferMagicLinkViewController(viewModel: viewModel)
        vc.delegate = self
        vc.configure()
        vc.modalPresentationStyle = .overCurrentContext

        viewController.navigationController?.present(vc, animated: true)
    }

    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        Task { @MainActor in
            do {
                let url = try await viewController.viewModel.generateTransferLink()
                displayShareUrlView(url: url, from: viewController, sender: sender)
            } catch {
                viewController.displayError(error: error)
            }
        }
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
