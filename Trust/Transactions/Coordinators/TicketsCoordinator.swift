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
    var scanQRCodeForWalletAddressToTransferTicketCoordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinator?
    var scanQRCodeForWalletAddressToSellTicketCoordinator: ScanQRCodeForWalletAddressToSellTicketCoordinator?

    init(
        session: WalletSession,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
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

    private func showChooseTicketSellModeViewController(for ticketHolder: TicketHolder,
                                                        linkExpiryDate: Date,
                                                        ethCost: String,
                                                        dollarCost: String,
                                                        in viewController: EnterSellTicketsDetailsViewController) {
        let vc = makeChooseTicketSellModeViewController(for: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: RedeemTicketsViewController) {
        let quantityViewController = makeRedeemTicketsQuantitySelectionViewController(for: ticketHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: SellTicketsViewController) {
        let quantityViewController = makeSellTicketsQuantitySelectionViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
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

    private func makeSellTicketsQuantitySelectionViewController(for ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> EnterSellTicketsDetailsViewController {
        let controller = EnterSellTicketsDetailsViewController(storage: tokensStorage, paymentFlow: paymentFlow)
        let viewModel = SellTicketsQuantitySelectionViewModel(ticketHolder: ticketHolder)
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
        let viewModel = ChooseTicketTransferModeViewControllerViewModel()
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeChooseTicketSellModeViewController(for ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) -> ChooseTicketSellModeViewController {
        let controller = ChooseTicketSellModeViewController(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, paymentFlow: paymentFlow)
        let viewModel = ChooseTicketSellModeViewControllerViewModel()
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func generateTransferLink(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> String {
        let timestamp = Int(NSDate().timeIntervalSince1970) + 86400
        let order = Order(
            price: BigUInt("0")!,
            indices: ticketHolder.ticketIndices,
            expiry: BigUInt(timestamp.description)!,
            contractAddress: Constants.fifaContractAddress,
            start: BigUInt("0")!,
            count: ticketHolder.ticketIndices.count
        )
        let orders = [order]
        let address = keystore.recentlyUsedWallet?.address
        let account = try! EtherKeystore().getAccount(for: address!)
        let signedOrders = try! OrderHandler().signOrders(orders: orders, account: account!)
        return UniversalLinkHandler().createUniversalLink(signedOrder: signedOrders[0])
    }

    private func generateSellLink(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) -> String {
        //TODO Generate sell link
        return "https://app.awallet.com/a_sell_link"
    }

    private func transferViaWalletAddressTextEntry(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        let controller = TransferTicketViaWalletAddressViewController(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        controller.delegate = self
        controller.configure(viewModel: .init(ticketHolder: ticketHolder))
        navigationController.pushViewController(controller, animated: true)
    }

    private func transferViaReadingWalletAddressFromQRCode(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        scanQRCodeForWalletAddressToTransferTicketCoordinator = ScanQRCodeForWalletAddressToTransferTicketCoordinator(ticketHolder: ticketHolder, paymentFlow: paymentFlow, in: navigationController)
        scanQRCodeForWalletAddressToTransferTicketCoordinator?.delegate = self
        scanQRCodeForWalletAddressToTransferTicketCoordinator?.start()
    }

    private func transferViaActivitySheet(ticketHolder: TicketHolder, paymentFlow: PaymentFlow, sender: UIView) {
        let url = generateTransferLink(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            //Be annoying if user copies and we close the transfer process
            if completed && activityType != UIActivityType.copyToPasteboard {
                self.navigationController.dismiss(animated: true)
            }
        }
        navigationController.present(vc, animated: true)
    }

    private func sellViaWalletAddressTextEntry(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) {
        let controller = SellTicketViaWalletAddressViewController(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, paymentFlow: paymentFlow)
        controller.delegate = self
        controller.configure(viewModel: .init(ticketHolder: ticketHolder))
        navigationController.pushViewController(controller, animated: true)
    }

    private func sellViaReadingWalletAddressFromQRCode(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) {
        scanQRCodeForWalletAddressToSellTicketCoordinator = ScanQRCodeForWalletAddressToSellTicketCoordinator(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, paymentFlow: paymentFlow, in: navigationController)
        scanQRCodeForWalletAddressToSellTicketCoordinator?.delegate = self
        scanQRCodeForWalletAddressToSellTicketCoordinator?.start()
    }

    private func sellViaActivitySheet(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) {
        let url = generateSellLink(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, paymentFlow: paymentFlow)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            //Be annoying if user copies and we close the sell process
            if completed && activityType != UIActivityType.copyToPasteboard {
                self.navigationController.dismiss(animated: true)
            }
        }
        navigationController.present(vc, animated: true)
    }

    private func transfer(ticketHolder: TicketHolder, to walletAddress: String, paymentFlow: PaymentFlow) {
        UIAlertController.alert(title: "", message: R.string.localizable.aWalletTicketTokenTransferModeWalletAddressConfirmation(walletAddress), alertButtonTitles: [R.string.localizable.aWalletTicketTokenTransferButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: navigationController) {
            guard $0 == 0 else { return }

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

    private func sell(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, to walletAddress: String, paymentFlow: PaymentFlow) {
        UIAlertController.alert(title: "", message: R.string.localizable.aWalletTicketTokenSellModeWalletAddressConfirmation(walletAddress), alertButtonTitles: [R.string.localizable.aWalletTicketTokenSellButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: navigationController) {
            guard $0 == 0 else { return }

            //Defensive. Should already be checked before this
            guard let address = Address(string: walletAddress) else {
                return self.navigationController.displayError(error: Errors.invalidAddress)
            }

            if case .real(let account) = self.session.account.type {
                let coordinator = SellTicketsCoordinator(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, walletAddress: walletAddress, paymentFlow: paymentFlow, keystore: self.keystore, session: self.session, account: account, on: self.navigationController)
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
        }
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

extension TicketsCoordinator: EnterSellTicketsDetailsViewControllerDelegate {
    func didEnterSellTicketDetails(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, in viewController: EnterSellTicketsDetailsViewController) {
        showChooseTicketSellModeViewController(for: ticketHolder, linkExpiryDate: linkExpiryDate, ethCost: ethCost, dollarCost: dollarCost, in: viewController)
    }

    func didPressViewInfo(in viewController: EnterSellTicketsDetailsViewController) {
        delegate?.didPressViewEthereumInfo(in: viewController)
    }
}

extension TicketsCoordinator: ChooseTicketTransferModeViewControllerDelegate {
    func didChoose(transferMode: TicketTransferMode, in viewController: ChooseTicketTransferModeViewController, sender: UIView) {
        let ticketHolder = viewController.ticketHolder

        switch transferMode {
        case .walletAddressTextEntry:
            transferViaWalletAddressTextEntry(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .walletAddressFromQRCode:
            transferViaReadingWalletAddressFromQRCode(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .other:
            transferViaActivitySheet(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow, sender: sender)
        }
    }
}

extension TicketsCoordinator: ChooseTicketSellModeViewControllerDelegate {
    func didChoose(sellMode: TicketSellMode, in viewController: ChooseTicketSellModeViewController) {
        let ticketHolder = viewController.ticketHolder

        switch sellMode {
        case .walletAddressTextEntry:
            sellViaWalletAddressTextEntry(ticketHolder: ticketHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, dollarCost: viewController.dollarCost, paymentFlow: viewController.paymentFlow)
        case .walletAddressFromQRCode:
            sellViaReadingWalletAddressFromQRCode(ticketHolder: ticketHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, dollarCost: viewController.dollarCost, paymentFlow: viewController.paymentFlow)
        case .other:
            sellViaActivitySheet(ticketHolder: ticketHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, dollarCost: viewController.dollarCost, paymentFlow: viewController.paymentFlow)
        }
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

extension TicketsCoordinator: TransferTicketViaWalletAddressViewControllerDelegate {
    func didChooseTransfer(to walletAddress: String, viewController: TransferTicketViaWalletAddressViewController) {
        transfer(ticketHolder: viewController.ticketHolder, to: walletAddress, paymentFlow: viewController.paymentFlow)
    }
}

extension TicketsCoordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinatorDelegate {
    func scanned(walletAddress: String, in coordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinator) {
        transfer(ticketHolder: coordinator.ticketHolder, to: walletAddress, paymentFlow: coordinator.paymentFlow)
    }

    func cancelled(in coordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinator) {
        //no-op
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

extension TicketsCoordinator: SellTicketsCoordinatorDelegate {
    private func cleanUpAfterSell(coordinator: SellTicketsCoordinator) {
        navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: SellTicketsCoordinator) {
        cleanUpAfterSell(coordinator: coordinator)
    }

    func didFinishSuccessfully(in coordinator: SellTicketsCoordinator) {
        cleanUpAfterSell(coordinator: coordinator)
    }

    func didFail(in coordinator: SellTicketsCoordinator) {
        cleanUpAfterSell(coordinator: coordinator)
    }
}

extension TicketsCoordinator: SellTicketViaWalletAddressViewControllerDelegate {
    func didChooseSell(to walletAddress: String, viewController: SellTicketViaWalletAddressViewController) {
        sell(ticketHolder: viewController.ticketHolder, linkExpiryDate: viewController.linkExpiryDate, ethCost: viewController.ethCost, dollarCost: viewController.dollarCost, to: walletAddress, paymentFlow: viewController.paymentFlow)
    }
}

extension TicketsCoordinator: ScanQRCodeForWalletAddressToSellTicketCoordinatorDelegate {
    func scanned(walletAddress: String, in coordinator: ScanQRCodeForWalletAddressToSellTicketCoordinator) {
        sell(ticketHolder: coordinator.ticketHolder, linkExpiryDate: coordinator.linkExpiryDate, ethCost: coordinator.ethCost, dollarCost: coordinator.dollarCost, to: walletAddress, paymentFlow: coordinator.paymentFlow)
    }

    func cancelled(in coordinator: ScanQRCodeForWalletAddressToSellTicketCoordinator) {
        //no-op
    }
}
