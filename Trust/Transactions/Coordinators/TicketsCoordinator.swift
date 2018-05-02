//  TicketsCoordinator.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/27/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result
import TrustKeystore
import MessageUI
import BigInt

protocol TicketsCoordinatorDelegate: class {
    func didPressTransfer(for type: PaymentFlow,
                          ticketHolders: [TicketHolder],
                          in coordinator: TicketsCoordinator)
    func didPressRedeem(for token: TokenObject,
                        in coordinator: TicketsCoordinator)
    func didPressSell(for type: PaymentFlow,
                      in coordinator: TicketsCoordinator)
    func didCancel(in coordinator: TicketsCoordinator)
    func didPressViewRedemptionInfo(in: UIViewController)
    func didPressViewEthereumInfo(in: UIViewController)
}

class TicketsCoordinator: NSObject, Coordinator {

    private let keystore: Keystore
    var token: TokenObject!
    var type: PaymentFlow!
    lazy var rootViewController: TicketsViewController = {
        return self.makeTicketsViewController(with: self.session.account)
    }()

    weak var delegate: TicketsCoordinatorDelegate?

    let session: WalletSession
    let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var ethPrice: Subscribable<Double>

    init(
        session: WalletSession,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        tokensStorage: TokensDataStore,
        ethPrice: Subscribable<Double>
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
        self.ethPrice = ethPrice
    }

    func start() {
        let viewModel = TicketsViewModel(
            token: token
        )
        rootViewController.tokenObject = token
        rootViewController.configure(viewModel: viewModel)
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTicketsViewController(with account: Wallet) -> TicketsViewController {
        let controller = TicketsViewController()
        controller.account = account
        controller.session = session
        controller.tokensStorage = tokensStorage
        controller.delegate = self
        return controller
    }

    func stop() {
        session.stop()
    }

    func showRedeemViewController() {
        let redeemViewController = makeRedeemTicketsViewController()
        navigationController.pushViewController(redeemViewController, animated: true)
    }

    func showSellViewController(for paymentFlow: PaymentFlow) {
        let sellViewController = makeSellTicketsViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(sellViewController, animated: true)
    }

    func showTransferViewController(for paymentFlow: PaymentFlow, ticketHolders: [TicketHolder]) {
        let transferViewController = makeTransferTicketsViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(transferViewController, animated: true)
    }

    private func showChooseTicketTransferModeViewController(for ticketHolder: TicketHolder,
                                                            in viewController: TransferTicketsQuantitySelectionViewController) {
        let vc = makeChooseTicketTransferModeViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showSaleConfirmationScreen(for ticketHolder: TicketHolder,
                                                        linkExpiryDate: Date,
                                                        ethCost: String,
                                                        in viewController: SetSellTicketsExpiryDateViewController) {
        let vc = makeGenerateSellMagicLinkViewController(paymentFlow: viewController.paymentFlow, ticketHolder: ticketHolder, ethCost: ethCost, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func showTransferConfirmationScreen(for ticketHolder: TicketHolder,
                                                        linkExpiryDate: Date,
                                                        in viewController: SetTransferTicketsExpiryDateViewController) {
        let vc = makeGenerateTransferMagicLinkViewController(paymentFlow: viewController.paymentFlow, ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate)
        viewController.navigationController?.present(vc, animated: true)
    }

    private func makeGenerateSellMagicLinkViewController(paymentFlow: PaymentFlow, ticketHolder: TicketHolder, ethCost: String, linkExpiryDate: Date) -> GenerateSellMagicLinkViewController{
        let vc = GenerateSellMagicLinkViewController(
                paymentFlow: paymentFlow,
                ticketHolder: ticketHolder,
                ethCost: ethCost,
                linkExpiryDate: linkExpiryDate
        )
        vc.delegate = self
        vc.configure(viewModel: .init(
                ticketHolder: ticketHolder,
                ethCost: ethCost,
                linkExpiryDate: linkExpiryDate
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }

    private func makeGenerateTransferMagicLinkViewController(paymentFlow: PaymentFlow, ticketHolder: TicketHolder, linkExpiryDate: Date) -> GenerateTransferMagicLinkViewController {
        let vc = GenerateTransferMagicLinkViewController(
                paymentFlow: paymentFlow,
                ticketHolder: ticketHolder,
                linkExpiryDate: linkExpiryDate
        )
        vc.delegate = self
        vc.configure(viewModel: .init(
                ticketHolder: ticketHolder,
                linkExpiryDate: linkExpiryDate
        ))
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }

    private func showEnterSellTicketsExpiryDateViewController(for ticketHolder: TicketHolder,
                                                        ethCost: String,
                                                        in viewController: EnterSellTicketsPriceQuantityViewController) {
        let vc = makeEnterSellTicketsExpiryDateViewController(for: ticketHolder, ethCost: ethCost, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: RedeemTicketsViewController) {
        let quantityViewController = makeRedeemTicketsQuantitySelectionViewController(for: ticketHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: SellTicketsViewController) {
        let vc = makeEnterSellTicketsPriceQuantityViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showTicketRedemptionViewController(for ticketHolder: TicketHolder,
                                                    in viewController: UIViewController) {
        let quantityViewController = makeTicketRedemptionViewController(for: ticketHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTicketsViewController() -> RedeemTicketsViewController {
        let controller = RedeemTicketsViewController()
        let viewModel = RedeemTicketsViewModel(token: token)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeSellTicketsViewController(paymentFlow: PaymentFlow) -> SellTicketsViewController {
        let controller = SellTicketsViewController(paymentFlow: paymentFlow)
        let viewModel = SellTicketsViewModel(token: token)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeRedeemTicketsQuantitySelectionViewController(for ticketHolder: TicketHolder) -> RedeemTicketsQuantitySelectionViewController {
        let controller = RedeemTicketsQuantitySelectionViewController()
        let viewModel = RedeemTicketsQuantitySelectionViewModel(ticketHolder: ticketHolder)
		controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTicketsPriceQuantityViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> EnterSellTicketsPriceQuantityViewController {
        let controller = EnterSellTicketsPriceQuantityViewController(storage: tokensStorage, paymentFlow: paymentFlow, ethPrice: ethPrice)
        let viewModel = EnterSellTicketsPriceQuantityViewControllerViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeEnterTransferTicketsExpiryDateViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> SetTransferTicketsExpiryDateViewController {
        let controller = SetTransferTicketsExpiryDateViewController(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let viewModel = SetTransferTicketsExpiryDateViewControllerViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeTransferTicketsViaWalletAddressViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> TransferTicketsViaWalletAddressViewController {
        let controller = TransferTicketsViaWalletAddressViewController(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let viewModel = TransferTicketsViaWalletAddressViewControllerViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeEnterSellTicketsExpiryDateViewController(for ticketHolder: TicketHolder, ethCost: String, paymentFlow: PaymentFlow) -> SetSellTicketsExpiryDateViewController {
        let controller = SetSellTicketsExpiryDateViewController(storage: tokensStorage, paymentFlow: paymentFlow, ticketHolder: ticketHolder, ethCost: ethCost)
        let viewModel = SetSellTicketsExpiryDateViewControllerViewModel(ticketHolder: ticketHolder, ethCost: ethCost)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeTicketRedemptionViewController(for ticketHolder: TicketHolder) -> TicketRedemptionViewController {
        let controller = TicketRedemptionViewController(session: session)
        let viewModel = TicketRedemptionViewModel(ticketHolder: ticketHolder)
		controller.configure(viewModel: viewModel)
        return controller
    }

    private func makeTransferTicketsViewController(paymentFlow: PaymentFlow) -> TransferTicketsViewController {
        let controller = TransferTicketsViewController(paymentFlow: paymentFlow)
        let viewModel = TransferTicketsViewModel(token: token)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: TransferTicketsViewController) {
        let quantityViewController = makeTransferTicketsQuantitySelectionViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeTransferTicketsQuantitySelectionViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> TransferTicketsQuantitySelectionViewController {
        let controller = TransferTicketsQuantitySelectionViewController(paymentFlow: paymentFlow)
        let viewModel = TransferTicketsQuantitySelectionViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeChooseTicketTransferModeViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> ChooseTicketTransferModeViewController {
        let controller = ChooseTicketTransferModeViewController(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let viewModel = ChooseTicketTransferModeViewControllerViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func generateTransferLink(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> String {
        let timestamp = Int(NSDate().timeIntervalSince1970) + 86400
        let order = Order(
            price: BigUInt("0")!,
            indices: ticketHolder.indices,
            expiry: BigUInt(timestamp.description)!,
            contractAddress: Constants.ticketContractAddress,
            start: BigUInt("0")!,
            count: ticketHolder.indices.count
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    private func generateSellLink(ticketHolder: TicketHolder,
                                  linkExpiryDate: Date,
                                  ethCost: String,
                                  paymentFlow: PaymentFlow) -> String {
        let cost = Decimal(string: ethCost)! * Decimal(string: "1000000000000000000")!
        let wei = BigUInt(cost.description)!
        let order = Order(
                price: wei,
                indices: ticketHolder.indices,
                expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
                contractAddress: Constants.ticketContractAddress,
                start: BigUInt("0")!,
                count: ticketHolder.indices.count
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    private func sellViaActivitySheet(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateSellLink(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, paymentFlow: paymentFlow)
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

    private func transferViaActivitySheet(ticketHolder: TicketHolder, linkExpiryDate: Date, paymentFlow: PaymentFlow, in viewController: UIViewController, sender: UIView) {
        let url = generateTransferLink(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
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

extension TicketsCoordinator: TicketsViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: TicketsViewController) {
        delegate?.didPressRedeem(for: token, in: self)
    }

    func didPressSell(for type: PaymentFlow, in viewController: TicketsViewController) {
        delegate?.didPressSell(for: type, in: self)
    }

    func didPressTransfer(for type: PaymentFlow, ticketHolders: [TicketHolder], in viewController: TicketsViewController) {
        delegate?.didPressTransfer(for: type, ticketHolders: ticketHolders, in: self)
    }

    func didCancel(in viewController: TicketsViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewRedemptionInfo(in viewController: TicketsViewController) {
       delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: RedeemTicketsViewControllerDelegate {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: RedeemTicketsViewController) {
        showQuantityViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTicketsViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: RedeemTicketsQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(ticketHolder: TicketHolder, in viewController: RedeemTicketsQuantitySelectionViewController) {
        showTicketRedemptionViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: RedeemTicketsQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: SellTicketsViewControllerDelegate {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: SellTicketsViewController) {
        showQuantityViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: SellTicketsViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TicketsCoordinator: TransferTicketsQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(ticketHolder: TicketHolder, in viewController: TransferTicketsQuantitySelectionViewController) {
        showChooseTicketTransferModeViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTicketsQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: EnterSellTicketsPriceQuantityViewControllerDelegate {
    func didEnterSellTicketsPriceQuantity(ticketHolder: TicketHolder, ethCost: String, in viewController: EnterSellTicketsPriceQuantityViewController) {
        showEnterSellTicketsExpiryDateViewController(for: ticketHolder, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTicketsPriceQuantityViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TicketsCoordinator: SetSellTicketsExpiryDateViewControllerDelegate {
    func didSetSellTicketsExpiryDate(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, in viewController: SetSellTicketsExpiryDateViewController) {
        showSaleConfirmationScreen(for: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, in: viewController)
    }

    func didPressViewInfo(in viewController: SetSellTicketsExpiryDateViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TicketsCoordinator: TransferTicketsViewControllerDelegate {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: TransferTicketsViewController) {
        showQuantityViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTicketsViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: TransferTicketsCoordinatorDelegate {
    private func cleanUpAfterTransfer(coordinator: TransferTicketsCoordinator) {
        navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: TransferTicketsCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
    }

    func didFinishSuccessfully(in coordinator: TransferTicketsCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
    }

    func didFail(in coordinator: TransferTicketsCoordinator) {
        cleanUpAfterTransfer(coordinator: coordinator)
    }
}

extension TicketsCoordinator: GenerateSellMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView) {
        sellViaActivitySheet(ticketHolder: viewController.ticketHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateSellMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TicketsCoordinator: ChooseTicketTransferModeViewControllerDelegate {
    func didChooseTransferViaMagicLink(ticketHolder: TicketHolder, in viewController: ChooseTicketTransferModeViewController) {
        let vc = makeEnterTransferTicketsExpiryDateViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didChooseTransferNow(ticketHolder: TicketHolder, in viewController: ChooseTicketTransferModeViewController) {
        let vc = makeTransferTicketsViaWalletAddressViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    func didPressViewInfo(in viewController: ChooseTicketTransferModeViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: SetTransferTicketsExpiryDateViewControllerDelegate {
    func didPressNext(ticketHolder: TicketHolder, linkExpiryDate: Date, in viewController: SetTransferTicketsExpiryDateViewController) {
        showTransferConfirmationScreen(for: ticketHolder, linkExpiryDate: linkExpiryDate, in: viewController)
    }

    func didPressViewInfo(in viewController: SetTransferTicketsExpiryDateViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: GenerateTransferMagicLinkViewControllerDelegate {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView) {
        transferViaActivitySheet(ticketHolder: viewController.ticketHolder, linkExpiryDate: viewController.linkExpiryDate, paymentFlow: viewController.paymentFlow, in: viewController, sender: sender)
    }

    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController) {
        viewController.dismiss(animated: true)
    }
}

extension TicketsCoordinator: TransferTicketsViaWalletAddressViewControllerDelegate {
    func didEnterWalletAddress(ticketHolder: TicketHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTicketsViaWalletAddressViewController) {
        UIAlertController.alert(title: "", message: R.string.localizable.aWalletTicketTokenTransferModeWalletAddressConfirmation(walletAddress), alertButtonTitles: [R.string.localizable.aWalletTicketTokenTransferButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: navigationController) {
            guard $0 == 0 else {
                return
            }

            //Defensive. Should already be checked before this
            guard let address = Address(string: walletAddress) else {
                return self.navigationController.displayError(error: Errors.invalidAddress)
            }

            if case .real(let account) = self.session.account.type {
                let coordinator = TransferTicketsCoordinator(ticketHolder: ticketHolder, walletAddress: walletAddress, paymentFlow: paymentFlow, keystore: self.keystore, session: self.session, account: account, on: self.navigationController)
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
        }
    }

    func didPressViewInfo(in viewController: TransferTicketsViaWalletAddressViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}
