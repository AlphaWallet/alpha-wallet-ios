// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import QRCodeReaderViewController

protocol ScanQRCodeForWalletAddressToTransferTicketCoordinatorDelegate: class {
    func scanned(walletAddress: String, in coordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinator)
    func cancelled(in coordinator: ScanQRCodeForWalletAddressToTransferTicketCoordinator)
}

class ScanQRCodeForWalletAddressToTransferTicketCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    var ticketHolder: TicketHolder
    var viewController: UIViewController
    var paymentFlow: PaymentFlow
    weak var delegate: ScanQRCodeForWalletAddressToTransferTicketCoordinatorDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow, in viewController: UIViewController) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow
        self.viewController = viewController
    }

    func start() {
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        viewController.present(controller, animated: true, completion: nil)
    }
}

extension ScanQRCodeForWalletAddressToTransferTicketCoordinator: QRCodeReaderDelegate {
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
