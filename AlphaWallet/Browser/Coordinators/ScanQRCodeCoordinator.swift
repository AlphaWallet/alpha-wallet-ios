// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import QRCodeReaderViewController
import BigInt
import PromiseKit
import AlphaWalletFoundation

protocol ScanQRCodeCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: ScanQRCodeCoordinator)
    func didScan(result: String, in coordinator: ScanQRCodeCoordinator)
}

final class ScanQRCodeCoordinator: NSObject, Coordinator {
    private let analytics: AnalyticsLogger
    private lazy var navigationController = NavigationController(rootViewController: qrcodeController)
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
    private let domainResolutionService: DomainResolutionServiceType

    let parentNavigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ScanQRCodeCoordinatorDelegate?

    init(analytics: AnalyticsLogger, navigationController: UINavigationController, account: Wallet?, domainResolutionService: DomainResolutionServiceType) {
        self.analytics = analytics
        self.account = account
        self.domainResolutionService = domainResolutionService
        self.parentNavigationController = navigationController
    }

    func start(fromSource source: Analytics.ScanQRCodeSource, clipboardString: String? = nil) {
        logStartScan(source: source)
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentNavigationController.present(navigationController, animated: true)

        if let valueFromClipboard = clipboardString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.reader(self.qrcodeController, didScanResult: valueFromClipboard)
            }
        }
    }

    @objc private func dismiss() {
        stopScannerAndDismiss {
            self.analytics.log(action: Analytics.Action.cancelScanQrCode)
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
            self.analytics.log(action: Analytics.Action.cancelScanQrCode)
            self.delegate?.didCancel(in: self)
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        stopScannerAndDismiss {
            infoLog("[QR Code] Scanned value: \(String(describing: result))")
            self.logCompleteScan(result: result)
            self.delegate?.didScan(result: result, in: self)
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, myQRCodeSelected sender: UIButton!) {
        //Showing QR code functionality is not available if there's no account, specifically when importing wallet during onboarding
        guard let account = account else { return }
        let coordinator = RequestCoordinator(navigationController: navigationController, account: account, domainResolutionService: domainResolutionService)
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

// MARK: Analytics
extension ScanQRCodeCoordinator {
    private func logCompleteScan(result: String) {
        let resultType = convertToAnalyticsResultType(value: result)
        analytics.log(action: Analytics.Action.completeScanQrCode, properties: [Analytics.Properties.resultType.rawValue: resultType.rawValue])
    }

    private func convertToAnalyticsResultType(value: String!) -> Analytics.ScanQRCodeResultType {
        if let resultType = QRCodeValueParser.from(string: value) {
            switch resultType {
            case .address:
                return .address
            case .eip681:
                break
            }
        }

        switch ScanQRCodeResolution(rawValue: value) {
        case .value:
            return .value
        case .other:
            return .other
        case .walletConnect:
            return .walletConnect
        case .url:
            return .url
        case .json:
            return .json
        case .privateKey:
            return .privateKey
        case .seedPhase:
            return .seedPhase
        }
    }

    private func logStartScan(source: Analytics.ScanQRCodeSource) {
        analytics.log(navigation: Analytics.Navigation.scanQrCode, properties: [Analytics.Properties.source.rawValue: source.rawValue])
    }
}
