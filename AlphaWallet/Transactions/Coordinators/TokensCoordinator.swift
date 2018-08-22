//  TokensCoordinator.swift
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

protocol TokensCoordinatorDelegate: class {
    func didPressTransfer(for type: PaymentFlow,
                          TokenHolders: [TokenHolder],
                          in coordinator: TokensCoordinator)
    func didPressRedeem(for token: TokenObject,
                        in coordinator: TokensCoordinator)
    func didPressSell(for type: PaymentFlow,
                      in coordinator: TokensCoordinator)
    func didCancel(in coordinator: TokensCoordinator)
    func didPressViewRedemptionInfo(in: UIViewController)
    func didPressViewEthereumInfo(in: UIViewController)
    func didPressViewContractWebPage(for token: TokenObject, in viewController: UIViewController)
}

class TokensCoordinator: NSObject, Coordinator {

    private let keystore: Keystore
    var token: TokenObject
    var type: PaymentFlow!
    lazy var rootViewController: TokensViewController = {
        let viewModel = TokensViewModel(token: token)
        return self.makeTokensViewController(with: self.session.account, viewModel: viewModel)
    }()

    weak var delegate: TokensCoordinatorDelegate?

    let session: WalletSession
    let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var ethPrice: Subscribable<Double>
    let assetDefinitionStore: AssetDefinitionStore

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
        rootViewController.tokenObject = token
        rootViewController.configure()
        navigationController.viewControllers = [rootViewController]
        refreshUponAssetDefinitionChanges()
    }

    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribe { [weak self] contract in
            guard let strongSelf = self else { return }
            guard contract.sameContract(as: strongSelf.token.contract) else { return }
            let viewModel = TokensViewModel(token: strongSelf.token)
            strongSelf.rootViewController.configure(viewModel: viewModel)
        }
    }

    private func makeTokensViewController(with account: Wallet, viewModel: TokensViewModel) -> TokensViewController {
        let controller = TokensViewController(config: session.config, tokenObject: token, account: account, session: session, tokensStorage: tokensStorage, viewModel: viewModel)
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
        let sellViewController = makeSellTokensViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(sellViewController, animated: true)
    }

    func showTransferViewController(for paymentFlow: PaymentFlow, TokenHolders: [TokenHolder]) {
        let transferViewController = makeTransferTokensViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(transferViewController, animated: true)
    }

    private func showChooseTokenTransferModeViewController(token: TokenObject,
                                                            for TokenHolder: TokenHolder,
                                                            in viewController: TransferTokensQuantitySelectionViewController) {
        let vc = makeChooseTokenTransferModeViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showSaleConfirmationScreen(for TokenHolder: TokenHolder,
                                            linkExpiryDate: Date,
                                            ethCost: String,
                                            in viewController: SetSellTokensExpiryDateViewController) {
        let vc = makeGenerateSellMagicLinkViewController(paymentFlow: viewController.paymentFlow, TokenHolder: TokenHolder, ethCost: ethCost, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func showTransferConfirmationScreen(for TokenHolder: TokenHolder,
                                                linkExpiryDate: Date,
                                                in viewController: SetTransferTokensExpiryDateViewController) {
        let vc = makeGenerateTransferMagicLinkViewController(paymentFlow: viewController.paymentFlow, TokenHolder: TokenHolder, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func makeGenerateSellMagicLinkViewController(paymentFlow: PaymentFlow, TokenHolder: TokenHolder, ethCost: String, linkExpiryDate: Date) -> GenerateSellMagicLinkViewController {
        let vc = GenerateSellMagicLinkViewController(
                paymentFlow: paymentFlow,
                TokenHolder: TokenHolder,
                ethCost: ethCost,
                linkExpiryDate: linkExpiryDate
        )
        vc.delegate = self
        vc.configure(viewModel: .init(
                TokenHolder: TokenHolder,
                ethCost: ethCost,
                linkExpiryDate: linkExpiryDate
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }

    private func makeGenerateTransferMagicLinkViewController(paymentFlow: PaymentFlow, TokenHolder: TokenHolder, linkExpiryDate: Date) -> GenerateTransferMagicLinkViewController {
        let vc = GenerateTransferMagicLinkViewController(
                paymentFlow: paymentFlow,
                TokenHolder: TokenHolder,
                linkExpiryDate: linkExpiryDate
        )
        vc.delegate = self
        vc.configure(viewModel: .init(
                TokenHolder: TokenHolder,
                linkExpiryDate: linkExpiryDate
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }

    private func showEnterSellTokensExpiryDateViewController(
            token: TokenObject,
            for TokenHolder: TokenHolder,
            ethCost: String,
            in viewController: EnterSellTokensPriceQuantityViewController) {
        let vc = makeEnterSellTokensExpiryDateViewController(token: token, for: TokenHolder, ethCost: ethCost, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showEnterQuantityViewController(token: TokenObject,
                                                 for TokenHolder: TokenHolder,
                                                 in viewController: RedeemTokensViewController) {
        let quantityViewController = makeRedeemTokensQuantitySelectionViewController(token: token, for: TokenHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func showEnterPriceQuantityViewController(for TokenHolder: TokenHolder,
                                                      in viewController: SellTokensViewController) {
        let vc = makeEnterSellTokensPriceQuantityViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showTokenRedemptionViewController(token: TokenObject,
                                                    for TokenHolder: TokenHolder,
                                                    in viewController: UIViewController) {
        let quantityViewController = makeTokenRedemptionViewController(token: token, for: TokenHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTokensViewController() -> RedeemTokensViewController {
        let viewModel = RedeemTokensViewModel(token: token)
        let controller = RedeemTokensViewController(config: session.config, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeSellTokensViewController(paymentFlow: PaymentFlow) -> SellTokensViewController {
        let viewModel = SellTokensViewModel(token: token)
        let controller = SellTokensViewController(config: session.config, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeRedeemTokensQuantitySelectionViewController(token: TokenObject, for TokenHolder: TokenHolder) -> RedeemTokensQuantitySelectionViewController {
        let viewModel = RedeemTokensQuantitySelectionViewModel(token: token, TokenHolder: TokenHolder)
        let controller = RedeemTokensQuantitySelectionViewController(config: session.config, token: token, viewModel: viewModel)
		controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensPriceQuantityViewController(token: TokenObject, for TokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> EnterSellTokensPriceQuantityViewController {
        let viewModel = EnterSellTokensPriceQuantityViewControllerViewModel(token: token, TokenHolder: TokenHolder)
        let controller = EnterSellTokensPriceQuantityViewController(config: session.config, storage: tokensStorage, paymentFlow: paymentFlow, ethPrice: ethPrice, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTokensExpiryDateViewController(token: TokenObject, for TokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> SetTransferTokensExpiryDateViewController {
        let viewModel = SetTransferTokensExpiryDateViewControllerViewModel(token: token, TokenHolder: TokenHolder)
        let controller = SetTransferTokensExpiryDateViewController(config: session.config, TokenHolder: TokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTransferTokensViaWalletAddressViewController(token: TokenObject, for TokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensViaWalletAddressViewController {
        let viewModel = TransferTokensViaWalletAddressViewControllerViewModel(token: token, TokenHolder: TokenHolder)
        let controller = TransferTokensViaWalletAddressViewController(config: session.config, token: token, TokenHolder: TokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTokensExpiryDateViewController(token: TokenObject, for TokenHolder: TokenHolder, ethCost: String, paymentFlow: PaymentFlow) -> SetSellTokensExpiryDateViewController {
        let viewModel = SetSellTokensExpiryDateViewControllerViewModel(token: token, TokenHolder: TokenHolder, ethCost: ethCost)
        let controller = SetSellTokensExpiryDateViewController(config: session.config, storage: tokensStorage, paymentFlow: paymentFlow, TokenHolder: TokenHolder, ethCost: ethCost, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeTokenRedemptionViewController(token: TokenObject, for TokenHolder: TokenHolder) -> TokenRedemptionViewController {
        let viewModel = TokenRedemptionViewModel(token: token, TokenHolder: TokenHolder)
        let controller = TokenRedemptionViewController(config: session.config, session: session, token: token, viewModel: viewModel)
		controller.configure()
        return controller
    }

    private func makeTransferTokensViewController(paymentFlow: PaymentFlow) -> TransferTokensViewController {
        let viewModel = TransferTokensViewModel(token: token)
        let controller = TransferTokensViewController(config: session.config, paymentFlow: paymentFlow, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func showEnterQuantityViewController(token: TokenObject,
                                                 for TokenHolder: TokenHolder,
                                                 in viewController: TransferTokensViewController) {
        let quantityViewController = makeTransferTokensQuantitySelectionViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeTransferTokensQuantitySelectionViewController(token: TokenObject, for TokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensQuantitySelectionViewController {
        let viewModel = TransferTokensQuantitySelectionViewModel(token: token, TokenHolder: TokenHolder)
        let controller = TransferTokensQuantitySelectionViewController(config: session.config, paymentFlow: paymentFlow, token: token, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func makeChooseTokenTransferModeViewController(token: TokenObject, for TokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> ChooseTokenTransferModeViewController {
        let viewModel = ChooseTokenTransferModeViewControllerViewModel(token: token, TokenHolder: TokenHolder)
        let controller = ChooseTokenTransferModeViewController(config: session.config, TokenHolder: TokenHolder, paymentFlow: paymentFlow, viewModel: viewModel)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func generateTransferLink(TokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow) -> String {
        let order = Order(
            price: BigUInt("0")!,
            indices: TokenHolder.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: TokenHolder.contractAddress,
            start: BigUInt("0")!,
            count: TokenHolder.indices.count
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    //note that the price must be in szabo for a sell link, price must be rounded
    private func generateSellLink(TokenHolder: TokenHolder,
                                  linkExpiryDate: Date,
                                  ethCost: String,
                                  paymentFlow: PaymentFlow) -> String {
        let ethCostRoundedTo4dp = String(format: "%.4f", Float(string: ethCost)!)
        let cost = Decimal(string: ethCostRoundedTo4dp)! * Decimal(string: "1000000000000000000")!
        let wei = BigUInt(cost.description)!
        let order = Order(
                price: wei,
                indices: TokenHolder.indices,
                expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
                contractAddress: TokenHolder.contractAddress,
                start: BigUInt("0")!,
                count: TokenHolder.indices.count
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    private func sellViaActivitySheet(TokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: String, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateSellLink(
            TokenHolder: TokenHolder,
            linkExpiryDate: linkExpiryDate,
            ethCost: ethCost,
            paymentFlow: paymentFlow
        )
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            //Be annoying if user copies and we close the sell process
            if completed && activityType != UIActivityType.copyToPasteboard {
                self.navigationController.dismiss(animated: false) {
                    self.delegate?.didCancel(in: self)
                }
            }
        }
        viewController.present(vc, animated: true)
    }

    private func transferViaActivitySheet(TokenHolder: TokenHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateTransferLink(TokenHolder: TokenHolder, linkExpiryDate: linkExpiryDate, paymentFlow: paymentFlow)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            //Be annoying if user copies and we close the transfer process
            if completed && activityType != UIActivityType.copyToPasteboard {
                self.navigationController.dismiss(animated: false) {
                    self.delegate?.didCancel(in: self)
                }
            }
        }
        viewController.present(vc, animated: true)
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: TokensViewController) {
        delegate?.didPressRedeem(for: token, in: self)
    }

    func didPressSell(for type: PaymentFlow, in viewController: TokensViewController) {
        delegate?.didPressSell(for: type, in: self)
    }

    func didPressTransfer(for type: PaymentFlow, TokenHolders: [TokenHolder], in viewController: TokensViewController) {
        delegate?.didPressTransfer(for: type, TokenHolders: TokenHolders, in: self)
    }

    func didCancel(in viewController: TokensViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewRedemptionInfo(in viewController: TokensViewController) {
       delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: TokensViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }

    func didTapURL(url: URL, in viewController: TokensViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCoordinator: RedeemTokensViewControllerDelegate {
    func didSelectTokenHolder(token: TokenObject, TokenHolder: TokenHolder, in viewController: RedeemTokensViewController) {
        showEnterQuantityViewController(token: token, for: TokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokensViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: RedeemTokensViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }

    func didTapURL(url: URL, in viewController: RedeemTokensViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCoordinator: RedeemTokensQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, TokenHolder: TokenHolder, in viewController: RedeemTokensQuantitySelectionViewController) {
        showTokenRedemptionViewController(token: token, for: TokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTokensQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: RedeemTokensQuantitySelectionViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: SellTokensViewControllerDelegate {
    func didSelectTokenHolder(TokenHolder: TokenHolder, in viewController: SellTokensViewController) {
        showEnterPriceQuantityViewController(for: TokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: SellTokensViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: SellTokensViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }

    func didTapURL(url: URL, in viewController: SellTokensViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCoordinator: TransferTokensQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(token: TokenObject, TokenHolder: TokenHolder, in viewController: TransferTokensQuantitySelectionViewController) {
        showChooseTokenTransferModeViewController(token: token, for: TokenHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTokensQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: TransferTokensQuantitySelectionViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: EnterSellTokensPriceQuantityViewControllerDelegate {
    func didEnterSellTokensPriceQuantity(token: TokenObject, TokenHolder: TokenHolder, ethCost: String, in viewController: EnterSellTokensPriceQuantityViewController) {
        showEnterSellTokensExpiryDateViewController(token: token, for: TokenHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTokensPriceQuantityViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: EnterSellTokensPriceQuantityViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: SetSellTokensExpiryDateViewControllerDelegate {
    func didSetSellTokensExpiryDate(TokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: String, in viewController: SetSellTokensExpiryDateViewController) {
        showSaleConfirmationScreen(for: TokenHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: SetSellTokensExpiryDateViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: SetSellTokensExpiryDateViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: TransferTokensViewControllerDelegate {
    func didSelectTokenHolder(token: TokenObject, TokenHolder: TokenHolder, in viewController: TransferTokensViewController) {
        switch token.type {
            case .erc721:
                let vc = makeTransferTokensViaWalletAddressViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
                viewController.navigationController?.pushViewController(vc, animated: true)
            case .erc875:
                showEnterQuantityViewController(token: token, for: TokenHolder, in: viewController)
            case .erc20: break
            case .ether: break
        }
    }

    func didPressViewInfo(in viewController: TransferTokensViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: TransferTokensViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }

    func didTapURL(url: URL, in viewController: TransferTokensViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension TokensCoordinator: TransferNFTCoordinatorDelegate {
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

extension TokensCoordinator: GenerateSellMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
        sellViaActivitySheet(TokenHolder: viewController.TokenHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TokensCoordinator: ChooseTokenTransferModeViewControllerDelegate {
    func didChooseTransferViaMagicLink(token: TokenObject, TokenHolder: TokenHolder, in viewController: ChooseTokenTransferModeViewController) {
        let vc = makeEnterTransferTokensExpiryDateViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(token: TokenObject, TokenHolder: TokenHolder, in viewController: ChooseTokenTransferModeViewController) {
        let vc = makeTransferTokensViaWalletAddressViewController(token: token, for: TokenHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didPressViewInfo(in viewController: ChooseTokenTransferModeViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: ChooseTokenTransferModeViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: SetTransferTokensExpiryDateViewControllerDelegate {
    func didPressNext(TokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensExpiryDateViewController) {
        showTransferConfirmationScreen(for: TokenHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTokensExpiryDateViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: SetTransferTokensExpiryDateViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}

extension TokensCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        transferViaActivitySheet(TokenHolder: viewController.TokenHolder, linkExpiryDate: viewController.linkExpiryDate, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TokensCoordinator: TransferTokensViaWalletAddressViewControllerDelegate {
    func didEnterWalletAddress(TokenHolder: TokenHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTokensViaWalletAddressViewController) {
        UIAlertController.alert(title: "", message: R.string.localizable.aWalletTokenTokenTransferModeWalletAddressConfirmation(walletAddress), alertButtonTitles: [R.string.localizable.aWalletTokenTokenTransferButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: navigationController) {
            guard $0 == 0 else {
                return
            }

            //Defensive. Should already be checked before this
            guard let _ = Address(string: walletAddress) else {
                return self.navigationController.displayError(error: Errors.invalidAddress)
            }

            if case .real(let account) = self.session.account.type {
                let coordinator = TransferNFTCoordinator(TokenHolder: TokenHolder, walletAddress: walletAddress, paymentFlow: paymentFlow, keystore: self.keystore, session: self.session, account: account, on: self.navigationController)
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
        }
    }

    func didPressViewInfo(in viewController: TransferTokensViaWalletAddressViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }

    func didPressViewContractWebPage(in viewController: TransferTokensViaWalletAddressViewController) {
        delegate?.didPressViewContractWebPage(for: viewController.viewModel.token, in: viewController)
    }
}
