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
import TrustKeystore
import MessageUI
import BigInt

protocol TokensCardCoordinatorDelegate: class, CanOpenURL {
    func didPressTransfer(for type: PaymentFlow,
                          tokenHolders: [TokenHolder],
                          in coordinator: TokensCardCoordinator)
    func didPressRedeem(for token: TokenObject,
                        in coordinator: TokensCardCoordinator)
    func didPressSell(for type: PaymentFlow,
                      in coordinator: TokensCardCoordinator)
    func didCancel(in coordinator: TokensCardCoordinator)
    func didPressViewRedemptionInfo(in: UIViewController)
    func didPressViewEthereumInfo(in: UIViewController)
}

class TokensCardCoordinator: NSObject, Coordinator {

    private let keystore: Keystore
    private let token: TokenObject
    private lazy var rootViewController: TokensCardViewController = {
        let viewModel = TokensCardViewModel(token: token)
        return makeTokensCardViewController(with: session.account, viewModel: viewModel)
    }()

    weak var delegate: TokensCardCoordinatorDelegate?

    private let session: WalletSession
    private let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    var isReadOnly = false {
        didSet {
            rootViewController.isReadOnly = isReadOnly
        }
    }
    init(
            session: WalletSession,
            navigationController: UINavigationController = NavigationController(),
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            token: TokenObject,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
        self.ethPrice = ethPrice
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        rootViewController.configure()
        navigationController.viewControllers = [rootViewController]
        refreshUponAssetDefinitionChanges()
    }

    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribe { [weak self] contract in
            guard let strongSelf = self else { return }
            guard contract.sameContract(as: strongSelf.token.contract) else { return }
            let viewModel = TokensCardViewModel(token: strongSelf.token)
            strongSelf.rootViewController.configure(viewModel: viewModel)
        }
    }

    private func makeTokensCardViewController(with account: Wallet, viewModel: TokensCardViewModel) -> TokensCardViewController {
        let controller = TokensCardViewController(config: session.config, tokenObject: token, account: account, tokensStorage: tokensStorage, viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    func stop() {
        session.stop()
    }

    func showRedeemViewController() {
        let redeemViewController = makeRedeemTokensViewController()
        navigationController.pushViewController(redeemViewController, animated: true)
    }

    func showSellViewController(for paymentFlow: PaymentFlow) {
        let sellViewController = makeSellTokensCardViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(sellViewController, animated: true)
    }

    func showTransferViewController(for paymentFlow: PaymentFlow, tokenHolders: [TokenHolder]) {
        let transferViewController = makeTransferTokensCardViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(transferViewController, animated: true)
    }

    private func showChooseTokensCardTransferModeViewController(token: TokenObject,
                                                                for tokenHolder: TokenHolder,
                                                                in viewController: TransferTokensCardQuantitySelectionViewController) {
        let vc = makeChooseTokenCardTransferModeViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
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
                linkExpiryDate: linkExpiryDate
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
                linkExpiryDate: linkExpiryDate
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
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showEnterQuantityViewController(token: TokenObject,
                                                 for tokenHolder: TokenHolder,
                                                 in viewController: RedeemTokenViewController) {
        let quantityViewController = makeRedeemTokensCardQuantitySelectionViewController(token: token, for: tokenHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func showEnterPriceQuantityViewController(for tokenHolder: TokenHolder,
                                                      in viewController: SellTokensCardViewController) {
        let vc = makeEnterSellTokensCardPriceQuantityViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showTokenCardRedemptionViewController(token: TokenObject,
                                                       for tokenHolder: TokenHolder,
                                                       in viewController: UIViewController) {
        let quantityViewController = makeTokenCardRedemptionViewController(token: token, for: tokenHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTokensViewController() -> RedeemTokenViewController {
        let viewModel = RedeemTokenCardViewModel(token: token)
        let controller = RedeemTokenViewController(config: session.config, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeSellTokensCardViewController(paymentFlow: PaymentFlow) -> SellTokensCardViewController {
        let viewModel = SellTokensCardViewModel(token: token)
        let controller = SellTokensCardViewController(config: session.config, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeRedeemTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> RedeemTokenCardQuantitySelectionViewController {
        let viewModel = RedeemTokenCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = RedeemTokenCardQuantitySelectionViewController(config: session.config, token: token, viewModel: viewModel)
		controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardPriceQuantityViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensCardPriceQuantityViewController {
        let viewModel = EnterSellTokensCardPriceQuantityViewControllerViewModel(token: token, tokenHolder: tokenHolder)
        let controller = EnterSellTokensCardPriceQuantityViewController(config: session.config, storage: tokensStorage, paymentFlow: paymentFlow, ethPrice: ethPrice, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensCardExpiryDateViewController {
        let viewModel = SetTransferTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder)
        let controller = SetTransferTokensCardExpiryDateViewController(config: session.config, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardViaWalletAddressViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardViaWalletAddressViewController {
        let viewModel = TransferTokensCardViaWalletAddressViewControllerViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TransferTokensCardViaWalletAddressViewController(config: session.config, token: token, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensCardExpiryDateViewController(token: TokenObject, for tokenHolder: TokenHolder, ethCost: Ether, paymentFlow: PaymentFlow) -> SetSellTokensCardExpiryDateViewController {
        let viewModel = SetSellTokensCardExpiryDateViewControllerViewModel(token: token, tokenHolder: tokenHolder, ethCost: ethCost)
        let controller = SetSellTokensCardExpiryDateViewController(config: session.config, storage: tokensStorage, paymentFlow: paymentFlow, tokenHolder: tokenHolder, ethCost: ethCost, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTokenCardRedemptionViewController(token: TokenObject, for tokenHolder: TokenHolder) -> TokenCardRedemptionViewController {
        let viewModel = TokenCardRedemptionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TokenCardRedemptionViewController(config: session.config, session: session, token: token, viewModel: viewModel)
		controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensCardViewController(paymentFlow: PaymentFlow) -> TransferTokensCardViewController {
        let viewModel = TransferTokensCardViewModel(token: token)
        let controller = TransferTokensCardViewController(config: session.config, paymentFlow: paymentFlow, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func showEnterQuantityViewController(token: TokenObject,
                                                 for tokenHolder: TokenHolder,
                                                 in viewController: TransferTokensCardViewController) {
        let quantityViewController = makeTransferTokensCardQuantitySelectionViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeTransferTokensCardQuantitySelectionViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardQuantitySelectionViewController {
        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: token, tokenHolder: tokenHolder)
        let controller = TransferTokensCardQuantitySelectionViewController(config: session.config, paymentFlow: paymentFlow, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeChooseTokenCardTransferModeViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenCardTransferModeViewController {
        let viewModel = ChooseTokenCardTransferModeViewControllerViewModel(token: token, tokenHolder: tokenHolder)
        let controller = ChooseTokenCardTransferModeViewController(config: session.config, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func generateTransferLink(tokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow) -> String {
        let order = Order(
            price: BigUInt("0")!,
            indices: tokenHolder.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: tokenHolder.contractAddress,
            start: BigUInt("0")!,
            count: tokenHolder.indices.count,
            tokenIds: [BigUInt]()
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    //note that the price must be in szabo for a sell link, price must be rounded
    private func generateSellLink(tokenHolder: TokenHolder,
                                  linkExpiryDate: Date,
                                  ethCost: Ether,
                                  paymentFlow: PaymentFlow) -> String {
        let ethCostRoundedTo5dp = String(format: "%.5f", Float(string: String(ethCost))!)
        let cost = Decimal(string: ethCostRoundedTo5dp)! * Decimal(string: "1000000000000000000")!
        let wei = BigUInt(cost.description)!
        let order = Order(
                price: wei,
                indices: tokenHolder.indices,
                expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
                contractAddress: tokenHolder.contractAddress,
                start: BigUInt("0")!,
                count: tokenHolder.indices.count,
                tokenIds: [BigUInt]()
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    private func sellViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateSellLink(
            tokenHolder: tokenHolder,
            linkExpiryDate: linkExpiryDate,
            ethCost: ethCost,
            paymentFlow: paymentFlow
        )
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            guard let strongSelf = self else { return }
            //Be annoying if user copies and we close the sell process
            if completed && activityType != UIActivityType.copyToPasteboard {
                strongSelf.navigationController.dismiss(animated: false) {
                    strongSelf.delegate?.didCancel(in: strongSelf)
                }
            }
        }
        viewController.present(vc, animated: true)
    }

    private func transferViaActivitySheet(tokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateTransferLink(tokenHolder: tokenHolder, linkExpiryDate: linkExpiryDate, paymentFlow: paymentFlow)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            guard let strongSelf = self else { return }
            //Be annoying if user copies and we close the transfer process
            if completed && activityType != UIActivityType.copyToPasteboard {
                strongSelf.navigationController.dismiss(animated: false) {
                    strongSelf.delegate?.didCancel(in: strongSelf)
                }
            }
        }
        viewController.present(vc, animated: true)
    }
}

extension TokensCardCoordinator: TokensCardViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: TokensCardViewController) {
        delegate?.didPressRedeem(for: token, in: self)
    }

    func didPressSell(for type: PaymentFlow, in viewController: TokensCardViewController) {
        delegate?.didPressSell(for: type, in: self)
    }

    func didPressTransfer(for type: PaymentFlow, tokenHolders: [TokenHolder], in viewController: TokensCardViewController) {
        delegate?.didPressTransfer(for: type, tokenHolders: tokenHolders, in: self)
    }

    func didCancel(in viewController: TokensCardViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewRedemptionInfo(in viewController: TokensCardViewController) {
       delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: TokensCardViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCardCoordinator: RedeemTokenViewControllerDelegate {
    func didSelectTokenHolder(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenViewController) {
        showEnterQuantityViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokenViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: RedeemTokenViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCardCoordinator: RedeemTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController) {
        showTokenCardRedemptionViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: SellTokensCardViewControllerDelegate {
    func didSelectTokenHolder(tokenHolder: TokenHolder, in viewController: SellTokensCardViewController) {
        showEnterPriceQuantityViewController(for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: SellTokensCardViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: SellTokensCardViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCardCoordinator: TransferTokenCardQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController) {
        showChooseTokensCardTransferModeViewController(token: token, for: tokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: EnterSellTokensCardPriceQuantityViewControllerDelegate {
    func didEnterSellTokensPriceQuantity(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController) {
        showEnterSellTokensCardExpiryDateViewController(token: token, for: tokenHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCoordinator: SetSellTokensCardExpiryDateViewControllerDelegate {
    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Ether, in viewController: SetSellTokensCardExpiryDateViewController) {
        showSaleConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCoordinator: TransferTokensCardViewControllerDelegate {
    func didSelectTokenHolder(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardViewController) {
        switch token.type {
            case .erc721:
                let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
                viewController.navigationController?.pushViewController(vc, animated: true)
            case .erc875:
                showEnterQuantityViewController(token: token, for: tokenHolder, in: viewController)
            case .erc20: break
            case .ether: break
        }
    }

    func didPressViewInfo(in viewController: TransferTokensCardViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didTapURL(url: URL, in viewController: TransferTokensCardViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCardCoordinator: TransferNFTCoordinatorDelegate {
    private func cleanUpAfterTransfer(coordinator: TransferNFTCoordinator) {
        navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: TransferNFTCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
    }

    func didFinishSuccessfully(in coordinator: TransferNFTCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
    }

    func didFail(in coordinator: TransferNFTCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
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
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(token: TokenObject, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController) {
        let vc = makeTransferTokensCardViaWalletAddressViewController(token: token, for: tokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didPressViewInfo(in viewController: ChooseTokenCardTransferModeViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TokensCardCoordinator: SetTransferTokensCardExpiryDateViewControllerDelegate {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController) {
        showTransferConfirmationScreen(for: tokenHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
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

extension TokensCardCoordinator: TransferTokensCardViaWalletAddressViewControllerDelegate {
    func didEnterWalletAddress(tokenHolder: TokenHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTokensCardViaWalletAddressViewController) {
        UIAlertController.alert(title: "", message: R.string.localizable.aWalletTokenTransferModeWalletAddressConfirmation(walletAddress), alertButtonTitles: [R.string.localizable.aWalletTokenTransferButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: navigationController) { [weak self] in
            guard let strongSelf = self else { return }
            guard $0 == 0 else { return }

            //Defensive. Should already be checked before this
            guard let _ = Address(string: walletAddress) else {
                return strongSelf.navigationController.displayError(error: Errors.invalidAddress)
            }

            if case .real(let account) = strongSelf.session.account.type {
                let coordinator = TransferNFTCoordinator(tokenHolder: tokenHolder, walletAddress: walletAddress, paymentFlow: paymentFlow, keystore: strongSelf.keystore, session: strongSelf.session, account: account, on: strongSelf.navigationController)
                coordinator.delegate = self
                coordinator.start()
                strongSelf.addCoordinator(coordinator)
            }
        }
    }

    func didPressViewInfo(in viewController: TransferTokensCardViaWalletAddressViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TokensCardCoordinator: TokenCardRedemptionViewControllerDelegate {
}

extension TokensCardCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
