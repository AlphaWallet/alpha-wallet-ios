// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import QRCodeReaderViewController

protocol ScanQRCodeForWalletAddressToSellTicketCoordinatorDelegate: class {
    func scanned(walletAddress: String, in coordinator: ScanQRCodeForWalletAddressToSellTicketCoordinator)
    func cancelled(in coordinator: ScanQRCodeForWalletAddressToSellTicketCoordinator)
}

class ScanQRCodeForWalletAddressToSellTicketCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    var ticketHolder: TicketHolder
    var viewController: UIViewController
    var linkExpiryDate: Date
    var ethCost: String
    var dollarCost: String
    var paymentFlow: PaymentFlow
    weak var delegate: ScanQRCodeForWalletAddressToSellTicketCoordinatorDelegate?

    init(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow, in viewController: UIViewController) {
        self.ticketHolder = ticketHolder
        self.linkExpiryDate = linkExpiryDate
        self.ethCost = ethCost
        self.dollarCost = dollarCost
        self.paymentFlow = paymentFlow
        self.viewController = viewController
    }

    func start() {
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension ScanQRCodeForWalletAddressToSellTicketCoordinator: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true) { [weak self] in
            if let celf = self {
                celf.delegate?.cancelled(in: celf)
            }
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true) { [weak self] in
            if let celf = self {
                celf.delegate?.scanned(walletAddress: result, in: celf)
            }
        }
    }
}
