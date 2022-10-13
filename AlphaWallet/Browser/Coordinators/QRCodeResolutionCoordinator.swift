//
//  QRCodeResolutionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.09.2020.
//

import Foundation
import BigInt
import PromiseKit
import AlphaWalletFoundation

protocol QRCodeResolutionCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveTransactionType transactionType: TransactionType, token: Token)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveWalletConnectURL url: AlphaWallet.WalletConnect.ConnectionUrl)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveString value: String)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveURL url: URL)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveJSON json: String)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveSeedPhase seedPhase: [String])
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolvePrivateKey privateKey: String)

    func didCancel(in coordinator: QRCodeResolutionCoordinator)
}

final class QRCodeResolutionCoordinator: Coordinator {
    enum Usage {
        case all(tokensService: TokenProvidable, importToken: ImportToken)
        case importWalletOnly
    }

    private let config: Config
    private let usage: Usage
    private var skipResolvedCodes: Bool = false
    private var navigationController: UINavigationController {
        scanQRCodeCoordinator.parentNavigationController
    }
    private let scanQRCodeCoordinator: ScanQRCodeCoordinator
    private let account: Wallet
    var coordinators: [Coordinator] = []
    weak var delegate: QRCodeResolutionCoordinatorDelegate?

    init(config: Config, coordinator: ScanQRCodeCoordinator, usage: Usage, account: Wallet) {
        self.config = config
        self.usage = usage
        self.scanQRCodeCoordinator = coordinator
        self.account = account
    }

    func start(fromSource source: Analytics.ScanQRCodeSource, clipboardString: String? = nil) {
        scanQRCodeCoordinator.delegate = self
        addCoordinator(scanQRCodeCoordinator)

        scanQRCodeCoordinator.start(fromSource: source, clipboardString: clipboardString)
    }
}

extension QRCodeResolutionCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        delegate?.didCancel(in: self)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        guard !skipResolvedCodes else { return }

        skipResolvedCodes = true
        resolveScanResult(result)
    }

    private func availableActions(forContract contract: AlphaWallet.Address) -> [ScanQRCodeAction] {
        switch usage {
        case .all(let tokensService, _):
            let isTokenFound = tokensService.token(for: contract, server: .main) != nil
            if isTokenFound {
                return [.sendToAddress, .watchWallet, .openInEtherscan]
            } else {
                return [.sendToAddress, .addCustomToken, .watchWallet, .openInEtherscan]
            }
        case .importWalletOnly:
            return [.watchWallet]
        }
    }

    private func resolveScanResult(_ rawValue: String) {
        guard let delegate = delegate else { return }
        let resolved = ScanQRCodeResolution(rawValue: rawValue)
        infoLog("[QR Code] resolved: \(resolved)")

        switch resolved {
        case .value(let value):
            switch value {
            case .address(let contract):
                let actions = availableActions(forContract: contract)
                if actions.count == 1 {
                    delegate.coordinator(self, didResolveAddress: contract, action: actions[0])
                } else {
                    showDidScanWalletAddress(for: actions, completion: { action in
                        delegate.coordinator(self, didResolveAddress: contract, action: action)
                    }, cancelCompletion: {
                        self.skipResolvedCodes = false
                    })
                }
            case .eip681(let protocolName, let address, let functionName, let params):
                switch usage {
                case .all(_, let importToken):
                    let resolver = Eip681UrlResolver(config: config, importToken: importToken, missingRPCServerStrategy: .fallbackToFirstMatching)
                    firstly {
                        resolver.resolve(protocolName: protocolName, address: address, functionName: functionName, params: params)
                    }.done { result in
                        switch result {
                        case .transaction(let transactionType, let token):
                            delegate.coordinator(self, didResolveTransactionType: transactionType, token: token)
                        case .address:
                            break // Not possible here
                        }
                    }.cauterize()
                case .importWalletOnly:
                    break
                }
            }
        case .other(let value):
            delegate.coordinator(self, didResolveString: value)
        case .walletConnect(let url):
            delegate.coordinator(self, didResolveWalletConnectURL: url)
        case .url(let url):
            showOpenURL(completion: {
                delegate.coordinator(self, didResolveURL: url)
            }, cancelCompletion: {
                //NOTE: we need to reset flag to false to make sure that next detected QR code will be handled
                self.skipResolvedCodes = false
            })
        case .json(let value):
            delegate.coordinator(self, didResolveJSON: value)
        case .privateKey(let value):
            delegate.coordinator(self, didResolvePrivateKey: value)
        case .seedPhase(let value):
            delegate.coordinator(self, didResolveSeedPhase: value)
        }
    }

    private func showDidScanWalletAddress(for actions: [ScanQRCodeAction], completion: @escaping (ScanQRCodeAction) -> Void, cancelCompletion: @escaping () -> Void) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: preferredStyle)

        for action in actions {
            let alertAction = UIAlertAction(title: action.title, style: .default) { _ in
                completion(action)
            }

            controller.addAction(alertAction)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            cancelCompletion()
        }

        controller.addAction(cancelAction)

        navigationController.present(controller, animated: true)
    }

    private func showOpenURL(completion: @escaping () -> Void, cancelCompletion: @escaping () -> Void) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: preferredStyle)

        let alertAction = UIAlertAction(title: R.string.localizable.qrCodeOpenInBrowserTitle(), style: .default) { _ in
            completion()
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            cancelCompletion()
        }

        controller.addAction(alertAction)
        controller.addAction(cancelAction)

        navigationController.present(controller, animated: true)
    }
}

extension ScanQRCodeAction {
    var title: String {
        switch self {
        case .sendToAddress:
            return R.string.localizable.qrCodeSendToAddressTitle()
        case .addCustomToken:
            return R.string.localizable.qrCodeAddCustomTokenTitle()
        case .watchWallet:
            return R.string.localizable.qrCodeWatchWalletTitle()
        case .openInEtherscan:
            return R.string.localizable.qrCodeOpenInEtherscanTitle()
        }
    }
}
