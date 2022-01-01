//  TokensCardCoordinator.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/27/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result
import SafariServices
import MessageUI
import BigInt

protocol TokensCardCoordinatorDelegate: class, CanOpenURL {
    func didCancel(in coordinator: TokensCardCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokensCardCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: TokensCardCoordinator)
}

class TokensCardCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: TokenObject
    private lazy var rootViewController: TokensCardViewController = {
        let viewModel = TokensCardViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        return makeTokensCardViewController(with: session.account, viewModel: viewModel)
    }()

    private let session: WalletSession
    private let tokensStorage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private weak var transferTokensViewController: TransferTokensCardViaWalletAddressViewController?
    private let analyticsCoordinator: AnalyticsCoordinator

    weak var delegate: TokensCardCoordinatorDelegate?
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
            analyticsCoordinator: AnalyticsCoordinator
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
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        rootViewController.configure()
        navigationController.pushViewController(rootViewController, animated: true)
        refreshUponAssetDefinitionChanges()
        refreshUponEthereumEventChanges()
    }

    func makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(type: PaymentFlow) {
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
            case let vc as TokensCardViewController:
                let viewModel = TokensCardViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
                vc.configure(viewModel: viewModel)
            case let vc as TokenInstanceViewController:
                let updatedTokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: session.account)
                let tokenHolder = vc.firstMatchingTokenHolder(fromTokenHolders: updatedTokenHolders)
                if let tokenHolder = tokenHolder {
                    let viewModel: TokenInstanceViewModel = .init(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
                    vc.configure(viewModel: viewModel)
                }
            case let vc as TokenInstanceActionViewController:
                //TODO it reloads, but doesn't live-reload the changes because the action contains the HTML and it doesn't change
                vc.configure()
            default:
                break
            }
        }
    }

    private func makeTokensCardViewController(with account: Wallet, viewModel: TokensCardViewModel) -> TokensCardViewController {
        let controller = TokensCardViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: token, account: account, tokensStorage: tokensStorage, assetDefinitionStore: assetDefinitionStore, viewModel: viewModel)
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self
        return controller
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
        let controller = RedeemTokenCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardPriceQuantityViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensCardPriceQuantityViewController {
        let viewModel = EnterSellTokensCardPriceQuantityViewControllerViewModel(token: token, tokenHolder: tokenHolder, server: session.server, assetDefinitionStore: assetDefinitionStore)
        let controller = EnterSellTokensCardPriceQuantityViewController(analyticsCoordinator: analyticsCoordinator, storage: tokensStorage, paymentFlow: paymentFlow, cryptoPrice: ethPrice, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensCardExpiryDateViewController {
        let viewModel = SetTransferTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = SetTransferTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, ethCost: Ether, paymentFlow: PaymentFlow) -> SetSellTokensCardExpiryDateViewController {
        let viewModel = SetSellTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, ethCost: ethCost, server: session.server, assetDefinitionStore: assetDefinitionStore)
        let controller = SetSellTokensCardExpiryDateViewController(analyticsCoordinator: analyticsCoordinator, storage: tokensStorage, paymentFlow: paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTokenCardRedemptionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> TokenCardRedemptionViewController {
        let viewModel = TokenCardRedemptionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TokenCardRedemptionViewController(session: session, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardQuantitySelectionViewController {
        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokensCardQuantitySelectionViewController(analyticsCoordinator: analyticsCoordinator, paymentFlow: paymentFlow, token: token, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeChooseTokenCardTransferModeViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenCardTransferModeViewController {
        let viewModel = ChooseTokenCardTransferModeViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = ChooseTokenCardTransferModeViewController(analyticsCoordinator: analyticsCoordinator, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
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

    //note that the price must be in szabo for a sell link, price must be rounded
    private func generateSellLink(tokenHolder: TokenHolder,
                                  linkExpiryDate: Date,
                                  ethCost: Ether,
                                  server: RPCServer) -> String {
        let ethCostRoundedTo5dp = String(format: "%.5f", Float(string: String(ethCost))!)
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
        let address = keystore.currentWallet.address
        let etherKeystore = try! EtherKeystore(analyticsCoordinator: analyticsCoordinator)
        let signedOrders = try! OrderHandler(keystore: etherKeystore).signOrders(orders: orders, account: address, tokenType: tokenHolder.tokenType)
        return UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrders[0], tokenType: tokenHolder.tokenType)
    }

    private func sellViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let server: RPCServer
        switch paymentFlow {
        case .send(let transactionType):
            server = transactionType.server
        case .request:
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

    private func showTokenInstanceViewController(tokenHolder: TokenHolder, in viewController: TokensCardViewController) {
        let vc = TokenInstanceViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: token, tokenHolder: tokenHolder, account: session.account, assetDefinitionStore: assetDefinitionStore)
        vc.delegate = self
        vc.configure()
        vc.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: UIViewController) {
        delegate?.didPress(for: .send(type: .tokenScript(action: action, tokenObject: token, tokenHolder: tokenHolder)), inViewController: viewController, in: self)
    }
}

extension TokensCardCoordinator: TokensCardViewControllerDelegate {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokensCardViewController) {
        showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokensCardViewController) {
        showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, for type: PaymentFlow, in viewController: TokensCardViewController) {
        switch token.type {
        case .erc721:
            delegate?.didPress(for: type, inViewController: viewController, in: self)
        case .erc875, .erc721ForTickets:
            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: type, in: viewController)
        case .nativeCryptocurrency, .erc20, .erc1155:
            break
        }
    }

    func didCancel(in viewController: TokensCardViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewRedemptionInfo(in viewController: TokensCardViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: TokensCardViewController) {
        let controller = SFSafariViewController(url: url)
        controller.makePresentationFullScreenForiOS13Migration()
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true)
    }

    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: TokensCardViewController) {
        showTokenInstanceViewController(tokenHolder: tokenHolder, in: viewController)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardViewController) {
        switch action.type {
        case .tokenScript:
            showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
        case .erc20Send, .erc20Receive, .nftRedeem, .nftSell, .nonFungibleTransfer, .swap, .buy, .bridge:
            //Couldn't have reached here
            break
        }
    }
}

extension TokensCardCoordinator: TokenInstanceViewControllerDelegate {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController) {
        showEnterQuantityViewControllerForRedeem(token: token, for: tokenHolder, in: viewController)
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController) {
        showEnterPriceQuantityViewController(tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController) {
        switch token.type {
        case .erc721:
            delegate?.didPress(for: paymentFlow, inViewController: viewController, in: self)
        case .erc875, .erc721ForTickets:
            showEnterQuantityViewControllerForTransfer(token: token, for: tokenHolder, forPaymentFlow: paymentFlow, in: viewController)
        case .nativeCryptocurrency, .erc20, .erc1155:
            break
        }
    }

    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: TokenInstanceViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController) {
        showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
    }
}

extension TokensCardCoordinator: RedeemTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showTokenCardRedemptionViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController) {
        showChooseTokensCardTransferModeViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {
    func didEnterSellTokensPriceQuantity(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {
    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, in viewController: SetSellTokensCardExpiryDateViewController) {
        showSaleConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController) {
        showViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCoordinator: GenerateSellMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
        sellViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TokensCardCoordinator: ChooseTokenCardTransferModeViewControllerDelegate {
    func didChooseTransferViaMagicLink(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let vc = makeEnterTransferTokensCardExpiryDateViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        vc.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let transactionType: TransactionType = .init(token: token, tokenHolders: [tokenHolder])
        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: viewController, in: self)
    }

    func didPressViewInfo(in viewController: ChooseTokenCardTransferModeViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: SetTransferTokensCardExpiryDateViewControllerDelegate {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController) {
        showTransferConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController) {
        showViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        transferViaActivitySheet(tokenHolder: viewController.tokenHolder, linkExpiryDate: viewController.linkExpiryDate, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TokensCardCoordinator: TokenCardRedemptionViewControllerDelegate {
}

extension TokensCardCoordinator: CanOpenURL {
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

extension TokensCardCoordinator: StaticHTMLViewControllerDelegate {
}
