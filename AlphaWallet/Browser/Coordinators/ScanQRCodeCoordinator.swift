// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import QRCodeReaderViewController
import BigInt
import PromiseKit

protocol ScanQRCodeCoordinatorDelegate: class {
    func didCancel(in coordinator: ScanQRCodeCoordinator)
    func didScan(result: String, in coordinator: ScanQRCodeCoordinator)
}

final class ScanQRCodeCoordinator: NSObject, Coordinator {
    private lazy var navigationController = UINavigationController(rootViewController: qrcodeController)
    private lazy var reader = QRCodeReader(metadataObjectTypes: [AVMetadataObject.ObjectType.qr])
    private lazy var qrcodeController: QRCodeReaderViewController = {
        let shouldShowMyQRCodeButton = account != nil
        let controller = QRCodeReaderViewController(
            cancelButtonTitle: nil,
            codeReader: reader,
            startScanningAtLoad: true,
            showSwitchCameraButton: false,
            showTorchButton: true,
            showMyQRCodeButton: shouldShowMyQRCodeButton,
            chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos(),
            bordersColor: Colors.qrCodeRectBorders,
            messageText: R.string.localizable.qrCodeTitle(),
            torchTitle: R.string.localizable.light(),
            torchImage: R.image.light(),
            chooseFromPhotoLibraryButtonImage: R.image.browse(),
            myQRCodeText: R.string.localizable.qrCodeMyqrCodeTitle(),
            myQRCodeImage: R.image.qrRoundedWhite()
        )
        controller.delegate = self
        controller.title = R.string.localizable.browserScanQRCodeTitle()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismiss))
        controller.delegate = self

        return controller
    }()
    private let account: Wallet?

    let parentNavigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ScanQRCodeCoordinatorDelegate?

    init(navigationController: UINavigationController, account: Wallet?) {
        self.account = account
        self.parentNavigationController = navigationController
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentNavigationController.present(navigationController, animated: true)
    }

    @objc private func dismiss() {
        stopScannerAndDismiss {
            self.delegate?.didCancel(in: self)
        }
    }

    private func stopScannerAndDismiss(completion: @escaping () -> Void) {
        reader.stopScanning()
        navigationController.dismiss(animated: true, completion: completion)
    }
}

extension ScanQRCodeCoordinator: QRCodeReaderDelegate {

    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        stopScannerAndDismiss {
            self.delegate?.didCancel(in: self)
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        stopScannerAndDismiss {
            self.delegate?.didScan(result: result, in: self)
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, myQRCodeSelected sender: UIButton!) {
        //Showing QR code functionality is not available if there's no account, specifically when importing wallet during onboarding
        guard let account = account else { return }
        let coordinator = RequestCoordinator(navigationController: navigationController, account: account)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension ScanQRCodeCoordinator: RequestCoordinatorDelegate {

    func didCancel(in coordinator: RequestCoordinator) {
        removeCoordinator(coordinator)

        coordinator.navigationController.popViewController(animated: true)
    }
}

extension UIBarButtonItem {

    static func cancelBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .cancel, target: target, action: selector)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.backWhite(), style: .plain, target: target, action: selector)
    }
}
