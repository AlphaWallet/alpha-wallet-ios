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

protocol NFTCollectionCoordinatorDelegate: class, CanOpenURL {
    func didCancel(in coordinator: NFTCollectionCoordinator)
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: NFTCollectionCoordinator)
    func didTap(transaction: TransactionInstance, in coordinator: NFTCollectionCoordinator)
    func didTap(activity: Activity, in coordinator: NFTCollectionCoordinator)
}

class NFTCollectionCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: TokenObject
    lazy var rootViewController: NFTCollectionViewController = {
        let viewModel = NFTCollectionViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        let controller = NFTCollectionViewController(keystore: keystore, session: session, assetDefinition: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, viewModel: viewModel, openSea: openSea, activitiesService: activitiesService, eventsDataStore: eventsDataStore)
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self

        return controller
    }()

    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let openSea: OpenSea
    private let activitiesService: ActivitiesServiceType
    weak var delegate: NFTCollectionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    private var cancelable = Set<AnyCancellable>()

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            token: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: NonActivityEventsDataStore,
            analyticsCoordinator: AnalyticsCoordinator,
            openSea: OpenSea,
            activitiesService: ActivitiesServiceType
    ) {
        self.activitiesService = activitiesService
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.openSea = openSea
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        rootViewController.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(closeDidSelect))
        navigationController.pushViewController(rootViewController, animated: true)
        subscribeForEthereumEventChanges()
    }

    @objc private func closeDidSelect(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
        delegate?.didCancel(in: self)
    }

    private func subscribeForEthereumEventChanges() {
        eventsDataStore
            .recentEventsChangeset(for: token.contractAddress)
            .filter({ changeset in
                switch changeset {
                case .update(let events, _, let insertions, let modifications):
                    return !insertions.map { events[$0] }.isEmpty || !modifications.map { events[$0] }.isEmpty
                case .initial, .error:
                    return false
                }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.refreshScreen()
            }).store(in: &cancelable)

        assetDefinitionStore
            .assetsSignatureOrBodyChange(for: token.contractAddress)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.refreshScreen()
            }).store(in: &cancelable)
    }

    private func refreshScreen() {
        for each in navigationController.viewControllers {
            switch each {
            case let vc as NFTCollectionViewController:
                let viewModel = NFTCollectionViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
                vc.configure(viewModel: viewModel)
            case let vc as NFTAssetViewController:
                let updatedTokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account)
                switch token.type {
                case .erc721, .erc875, .erc721ForTickets:
                    let tokenHolder = vc.viewModel.firstMatchingTokenHolder(from: updatedTokenHolders)
                    if let tokenHolder = tokenHolder {
                        let viewModel = NFTAssetViewModel(account: session.account, tokenId: tokenHolder.tokenId, token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
                        vc.configure(viewModel: viewModel)
                    }
                case .erc1155:
                    if let selection = vc.viewModel.isMatchingTokenHolder(from: updatedTokenHolders) {
                        let viewModel: NFTAssetViewModel = .init(account: session.account, tokenId: selection.tokenId, token: token, tokenHolder: selection.tokenHolder, assetDefinitionStore: assetDefinitionStore)
                        vc.configure(viewModel: viewModel)
                    }
                case .nativeCryptocurrency, .erc20:
                    break
                }
            case let vc as TokenInstanceActionViewController:
                //TODO it reloads, but doesn't live-reload the changes because the action contains the HTML and it doesn't change
                vc.configure()
            default:
                break
            }
        }
    }

    func stop() {
        session.stop()
    }

    private func showChooseTokensCardTransferModeViewController(token: TokenObject,
                                                                for tokenHolder: TokenHolder,
                                                                in viewController: TransferTokensCardQuantitySelectionViewController) {
        let vc = makeChooseTokenCardTransferModeViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showSaleConfirmationScreen(for tokenHolder: TokenHolder,
                                            linkExpiryDate: Date,
                                            ethCost: Ether,
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

    private func makeGenerateSellMagicLinkViewController(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, ethCost: Ether, linkExpiryDate: Date) -> GenerateSellMagicLinkViewController {
        let vc = GenerateSellMagicLinkViewController(
                paymentFlow: paymentFlow,
                tokenHolder: tokenHolder,
                ethCost: ethCost,
                linkExpiryDate: linkExpiryDate
        )
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
            token: TokenObject,
            for tokenHolder: TokenHolder,
            ethCost: Ether,
            in viewController: EnterSellTokensCardPriceQuantityViewController) {
        let vc = makeEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showEnterQuantityViewControllerForRedeem(token: TokenObject, for tokenHolder: TokenHolder, in viewController: UIViewController) {
        let quantityViewController = makeRedeemTokensCardQuantitySelectionViewController(token: token, for: tokenHolder)
        quantityViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(quantityViewController, animated: true)
    }

    private func showEnterQuantityViewControllerForTransfer(token: TokenObject, for tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: UIViewController) {
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

    private func showTokenCardRedemptionViewController(token: TokenObject,
                                                       for tokenHolder: TokenHolder,
                                                       in viewController: UIViewController) {
        let quantityViewController = makeTokenCardRedemptionViewController(token: token, for: tokenHolder)
        quantityViewController.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> RedeemTokenCardQuantitySelectionViewController {
        let viewModel = RedeemTokenCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = RedeemTokenCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardPriceQuantityViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensCardPriceQuantityViewController {
        let viewModel = EnterSellTokensCardPriceQuantityViewControllerViewModel(token: token, tokenHolder: tokenHolder, server: session.server, assetDefinitionStore: assetDefinitionStore)
        let controller = EnterSellTokensCardPriceQuantityViewController(analyticsCoordinator: analyticsCoordinator, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, walletSession: session, keystore: keystore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensCardExpiryDateViewController {
        let viewModel = SetTransferTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = SetTransferTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, ethCost: Ether, paymentFlow: PaymentFlow) -> SetSellTokensCardExpiryDateViewController {
        let viewModel = SetSellTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, ethCost: ethCost, server: session.server, assetDefinitionStore: assetDefinitionStore)
        let controller = SetSellTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, paymentFlow: paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTokenCardRedemptionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> TokenCardRedemptionViewController {
        let viewModel = TokenCardRedemptionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TokenCardRedemptionViewController(session: session, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, keystore: keystore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardQuantitySelectionViewController {
        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokensCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, paymentFlow: paymentFlow, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeChooseTokenCardTransferModeViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenCardTransferModeViewController {
        let viewModel = ChooseTokenCardTransferModeViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = ChooseTokenCardTransferModeViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
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
        let address = session.account.address
        let signedOrders = try! OrderHandler(keystore: keystore).signOrders(orders: orders, account: address, tokenType: tokenHolder.tokenType)
        return UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrders[0], tokenType: tokenHolder.tokenType)
    }

    //note that the price must be in szabo for a sell link, price must be rounded
    private func generateSellLink(tokenHolder: TokenHolder,
                                  linkExpiryDate: Date,
                                  ethCost: Ether,
                                  server: RPCServer) -> String {
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
                nativeCurrencyDrop: false
        )
        let orders = [order]
        let address = session.account.address
        let signedOrders = try! OrderHandler(keystore: keystore).signOrders(orders: orders, account: address, tokenType: tokenHolder.tokenType)
        return UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrders[0], tokenType: tokenHolder.tokenType)
    }

    private func sellViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let server: RPCServer
        switch paymentFlow {
        case .send(let transactionType):
            server = transactionType.server
        case .request, .swap:
            return
        }
        let url = generateSellLink(
            tokenHolder: tokenHolder,
            linkExpiryDate: linkExpiryDate,
            ethCost: ethCost,
            server: server
        )
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            guard let strongSelf = self else { return }
            //Be annoying if user copies and we close the sell process
            if completed && activityType != UIActivity.ActivityType.copyToPasteboard {
                strongSelf.navigationController.dismiss(animated: false) {
                    strongSelf.delegate?.didCancel(in: strongSelf)
                }
            }
        }
        viewController.present(vc, animated: true)
    }

    private func transferViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let server: RPCServer
        switch paymentFlow {
        case .send(let transactionType):
            server = transactionType.server
        case .request, .swap:
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
        showTokenCardSelection(tokenHolders: viewController.viewModel.tokenHolders)
    }

    func didTap(transaction: TransactionInstance, in viewController: NFTCollectionViewController) {
        delegate?.didTap(transaction: transaction, in: self)
    }

    func didTap(activity: Activity, in viewController: NFTCollectionViewController) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        showNFTAsset(tokenHolder: tokenHolder, navigationController: viewController.navigationController)
    }

    func showNFTAsset(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive) {
        showNFTAsset(tokenHolder: tokenHolder, mode: mode, navigationController: navigationController)
    }

    private func showNFTAsset(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive, navigationController: UINavigationController?) {
        let vc: UIViewController
        switch tokenHolder.type {
        case .collectible:
            vc = createNFTAssetListViewController(tokenHolder: tokenHolder)
        case .single:
            vc = createNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: mode)
        }

        vc.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: { _ in
            navigationController?.popViewController(animated: true)
        })

        navigationController?.pushViewController(vc, animated: true)
    }

    private func createNFTAssetListViewController(tokenHolder: TokenHolder) -> NFTAssetListViewController {
        let viewModel = NFTAssetListViewModel(tokenHolder: tokenHolder)
        let tokenCardViewFactory: TokenCardViewFactory = {
            TokenCardViewFactory(token: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: session.account)
        }()
        let vc = NFTAssetListViewController(viewModel: viewModel, tokenCardViewFactory: tokenCardViewFactory)
        vc.delegate = self
        return vc
    }

    private func createNFTAssetViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode = .interactive) -> UIViewController {
        let viewModel = NFTAssetViewModel(account: session.account, tokenId: tokenId, token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let vc = NFTAssetViewController(analyticsCoordinator: analyticsCoordinator, openSea: openSea, session: session, assetDefinitionStore: assetDefinitionStore, keystore: keystore, viewModel: viewModel, mode: mode)
        vc.delegate = self
        vc.navigationItem.largeTitleDisplayMode = .never

        return vc
    }

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: NFTCollectionViewController) {
        showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: NFTCollectionViewController) {
        showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didCancel(in viewController: NFTCollectionViewController) {
        delegate?.didCancel(in: self)
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
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: { _ in
            viewController.navigationController?.popViewController(animated: true)
        })

        viewController.navigationController?.pushViewController(vc, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTAssetListViewControllerDelegate {
    func selectTokenCardsSelected(in viewController: NFTAssetListViewController) {
        showTokenCardSelection(tokenHolders: [viewController.tokenHolder])
    }

    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenId: TokenId) {
        let vc = createNFTAssetViewController(tokenHolder: viewController.tokenHolder, tokenId: tokenId)
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: { _ in
            viewController.navigationController?.popViewController(animated: true)
        })

        viewController.navigationController?.pushViewController(vc, animated: true)
    }
}

extension NFTCollectionCoordinator: NFTAssetSelectionCoordinatorDelegate {

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let tokenCardViewFactory: TokenCardViewFactory = {
            TokenCardViewFactory(token: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: session.account)
        }()
        let coordinator = NFTAssetSelectionCoordinator(navigationController: navigationController, tokenObject: token, tokenHolders: tokenHolders, tokenCardViewFactory: tokenCardViewFactory)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func didTapSend(in coordinator: NFTAssetSelectionCoordinator, tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)

        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        guard let vc = navigationController.visibleViewController else { return }
        let transactionType: TransactionType = .erc1155Token(tokenObject, transferType: .singleTransfer, tokenHolders: filteredTokenHolders)
        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: vc, in: self)
    }

    func didFinish(in coordinator: NFTAssetSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension NFTCollectionCoordinator: NonFungibleTokenViewControllerDelegate {

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: NFTAssetViewController) {
        switch token.type {
        case .erc721:
            delegate?.didPress(for: paymentFlow, inViewController: viewController, in: self)
        case .erc875, .erc721ForTickets:
            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
        case .nativeCryptocurrency, .erc20:
            break
        case .erc1155:
            let transactionType: TransactionType = .erc1155Token(token, transferType: .singleTransfer, tokenHolders: [tokenHolder])
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
        delegate?.didPress(for: .send(type: .tokenScript(action: action, tokenObject: token, tokenHolder: tokenHolder)), inViewController: viewController, in: self)
    }

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: NFTAssetViewController) {
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
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showTokenCardRedemptionViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController) {
        showChooseTokensCardTransferModeViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {
    func didEnterSellTokensPriceQuantity(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension NFTCollectionCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {
    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, in viewController: SetSellTokensCardExpiryDateViewController) {
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
    func didChooseTransferViaMagicLink(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let vc = makeEnterTransferTokensCardExpiryDateViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
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

extension Collection where Element == UnconfirmedTransaction.TokenIdAndValue {
    var erc1155TokenTransactionType: Erc1155TokenTransactionType {
        return count > 1 ? .batchTransfer : .singleTransfer
    }
}
