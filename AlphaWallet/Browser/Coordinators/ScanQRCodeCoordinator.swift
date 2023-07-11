// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import QRCodeReaderViewController
import BigInt
import AlphaWalletFoundation
import AlphaWalletLogger

protocol ScanQRCodeCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: ScanQRCodeCoordinator)
    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator)
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
            bordersColor: Configuration.Color.Semantic.qrCodeRectBorders,
            messageText: R.string.localizable.qrCodeTitle(),
            torchTitle: R.string.localizable.light(),
            torchImage: R.image.light(),
            chooseFromPhotoLibraryButtonImage: R.image.browse(),
            myQRCodeText: R.string.localizable.qrCodeMyqrCodeTitle(),
            myQRCodeImage: R.image.qrRoundedWhite()
        )
        controller.delegate = self
        controller.title = R.string.localizable.browserScanQRCodeTitle()
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismissButtonSelected))
        controller.delegate = self

        return controller
    }()
    private let account: Wallet?
    private let domainResolutionService: DomainNameResolutionServiceType

    let parentNavigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ScanQRCodeCoordinatorDelegate?

    init(analytics: AnalyticsLogger,
         navigationController: UINavigationController,
         account: Wallet?,
         domainResolutionService: DomainNameResolutionServiceType) {

        self.analytics = analytics
        self.account = account
        self.domainResolutionService = domainResolutionService
        self.parentNavigationController = navigationController
    }

    func start(fromSource source: Analytics.ScanQRCodeSource, clipboardString: String? = nil) {
        CameraDonation().donate()
        logStartScan(source: source)
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentNavigationController.present(navigationController, animated: true)

        if let valueFromClipboard = clipboardString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.reader(self.qrcodeController, didScanResult: valueFromClipboard)
            }
        }
    }

    @objc private func dismissButtonSelected() {
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
            let result = result.trimmed
            infoLog("[QR Code] Scanned value: \(String(describing: result))")
            Task { @MainActor in
                let decodedValue = await QrCodeValue(string: result)
                self.logCompleteScan(result: result, decodedValue: decodedValue)
                self.delegate?.didScan(result: result, decodedValue: decodedValue, in: self)
            }
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
    private func logCompleteScan(result: String, decodedValue: QrCodeValue) {
        let resultType = convertToAnalyticsResultType(value: result, decodedValue: decodedValue)
        analytics.log(action: Analytics.Action.completeScanQrCode, properties: [Analytics.Properties.resultType.rawValue: resultType.rawValue])
    }

    private func convertToAnalyticsResultType(value: String!, decodedValue: QrCodeValue) -> Analytics.ScanQRCodeResultType {
        if let resultType = AddressOrEip681Parser.from(string: value) {
            switch resultType {
            case .address:
                return .address
            case .eip681:
                break
            }
        }

        //TODO not sure it's desirable to parse and interpret the attestation again (if it's one) just for logging. Involves smart contract calls. It should be done elsewhere already
        switch decodedValue {
        case .addressOrEip681:
            return .addressOrEip681
        case .string:
            return .string
        case .walletConnect:
            return .walletConnect
        case .url:
            return .url
        case .json:
            return .json
        case .privateKey:
            return .privateKey
        case .seedPhase:
            return .seedPhrase
        case .attestation:
            return .attestation
        }
    }

    private func logStartScan(source: Analytics.ScanQRCodeSource) {
        analytics.log(navigation: Analytics.Navigation.scanQrCode, properties: [Analytics.Properties.source.rawValue: source.rawValue])
    }
}
