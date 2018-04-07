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

protocol TicketsCoordinatorDelegate: class {
    func didPressTransfer(for type: PaymentFlow,
                          ticketHolders: [TicketHolder],
                          in coordinator: TicketsCoordinator)
    func didPressRedeem(for token: TokenObject,
                        in coordinator: TicketsCoordinator)
    func didCancel(in coordinator: TicketsCoordinator)
    func didPressViewRedemptionInfo(in: UIViewController)
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

    func showTransferViewController(for paymentFlow: PaymentFlow, ticketHolders: [TicketHolder]) {
        let redeemViewController = makeTransferTicketsViewController(paymentFlow: paymentFlow)
        navigationController.pushViewController(redeemViewController, animated: true)
    }

    private func showChooseTicketTransferModeViewController(for ticketHolder: TicketHolder,
                                                            in viewController: TransferTicketsQuantitySelectionViewController) {
        let vc = makeChooseTicketTransferModeViewController(for: ticketHolder, paymentFlow: viewController.paymentFlow)
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: RedeemTicketsViewController) {
        let quantityViewController = makeRedeemTicketsQuantitySelectionViewController(for: ticketHolder)
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

    private func makeRedeemTicketsQuantitySelectionViewController(for ticketHolder: TicketHolder) -> RedeemTicketsQuantitySelectionViewController {
        let controller = RedeemTicketsQuantitySelectionViewController()
        let viewModel = RedeemTicketsQuantitySelectionViewModel(ticketHolder: ticketHolder)
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

    private func transferViaText(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        guard MFMessageComposeViewController.canSendText() else {
            UIAlertController.alert(title: "", message: R.string.localizable.aSetupReminderTextText(), alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: navigationController, completion: nil)
            return
        }

        let url = generateTransferLink(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = self
        vc.body = url
        navigationController.present(vc, animated: true)
    }

    private func transferViaEmail(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        guard MFMailComposeViewController.canSendMail() else {
            UIAlertController.alert(title: "", message: R.string.localizable.aSetupReminderEmailText(), alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: navigationController, completion: nil)
            return
        }

        let url = generateTransferLink(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let vc = MFMailComposeViewController()
        vc.setMessageBody(url, isHTML: false)
        vc.mailComposeDelegate = self
        navigationController.present(vc, animated: true)
    }

    private func generateTransferLink(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) -> String {
        //TODO replace with transfer link generated from ticketHolder and paymentFlow
        return "https://app.alphawallet.io/something"
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

    private func transferViaActivitySheet(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        let url = generateTransferLink(ticketHolder: ticketHolder, paymentFlow: paymentFlow)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            //Be annoying if user copies and we close the transfer process
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
}

extension TicketsCoordinator: TicketsViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: TicketsViewController) {
        delegate?.didPressRedeem(for: token, in: self)
    }

    func didPressSell(token: TokenObject, in viewController: TicketsViewController) {
        UIAlertController.alert(title: "",
                                message: "This feature is not yet implemented",
                                alertButtonTitles: ["OK"],
                                alertButtonStyles: [.cancel],
                                viewController: viewController,
                                completion: nil)
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

extension TicketsCoordinator: TransferTicketsQuantitySelectionViewControllerDelegate {
    func didSelectQuantity(ticketHolder: TicketHolder, in viewController: TransferTicketsQuantitySelectionViewController) {
        showChooseTicketTransferModeViewController(for: ticketHolder, in: viewController)
    }

    func didPressViewInfo(in viewController: TransferTicketsQuantitySelectionViewController) {
        delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: ChooseTicketTransferModeViewControllerDelegate {
    func didChoose(transferMode: TicketTransferMode, in viewController: ChooseTicketTransferModeViewController) {
        let ticketHolder = viewController.ticketHolder

        switch transferMode {
        case .text:
            transferViaText(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .email:
            transferViaEmail(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .walletAddressTextEntry:
            transferViaWalletAddressTextEntry(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .walletAddressFromQRCode:
            transferViaReadingWalletAddressFromQRCode(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
        case .other:
            transferViaActivitySheet(ticketHolder: ticketHolder, paymentFlow: viewController.paymentFlow)
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

extension TicketsCoordinator: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        if result == .cancelled || result == .failed {
            controller.dismiss(animated: true)
        } else {
            controller.dismiss(animated: false)
            navigationController.dismiss(animated: true)
        }
    }
}

extension TicketsCoordinator: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if result == .cancelled || result == .failed {
            controller.dismiss(animated: true)
        } else {
            controller.dismiss(animated: false)
            navigationController.dismiss(animated: true)
        }
    }
}
