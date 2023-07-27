//
//  QRCodeResolutionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.09.2020.
//

import Foundation
import BigInt
import AlphaWalletAttestation
import AlphaWalletFoundation
import AlphaWalletLogger
import Combine

enum QrCodeResolution {
    case address(address: AlphaWallet.Address, action: ScanQRCodeAction)
    case transactionType(transactionType: TransactionType, token: Token)
    case walletConnectUrl(url: AlphaWallet.WalletConnect.ConnectionUrl)
    case string(value: String)
    case url(url: URL)
    case json(json: String)
    case seedPhase(seedPhase: [String])
    case privateKey(privateKey: String)
    case attestation(attestation: Attestation)
}

protocol QRCodeResolutionCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolve qrCodeResolution: QrCodeResolution)
    func didCancel(in coordinator: QRCodeResolutionCoordinator)
}

final class QRCodeResolutionCoordinator: Coordinator {
    enum Usage {
        case all(tokensService: TokensService, sessionsProvider: SessionsProvider)
        case importWalletOnly
    }

    private let usage: Usage
    private var skipResolvedCodes: Bool = false
    private var navigationController: UINavigationController {
        scanQRCodeCoordinator.parentNavigationController
    }
    private let scanQRCodeCoordinator: ScanQRCodeCoordinator
    private var cancellable = Set<AnyCancellable>()
    private let supportedResolutions: Set<SupportedQrCodeResolution>

    var coordinators: [Coordinator] = []
    weak var delegate: QRCodeResolutionCoordinatorDelegate?

    init(coordinator: ScanQRCodeCoordinator,
         usage: Usage,
         supportedResolutions: Set<SupportedQrCodeResolution> = Set(SupportedQrCodeResolution.allCases)) {

        self.supportedResolutions = supportedResolutions
        self.usage = usage
        self.scanQRCodeCoordinator = coordinator
    }

    func start(fromSource source: Analytics.ScanQRCodeSource,
               clipboardString: String? = nil) {

        scanQRCodeCoordinator.delegate = self
        addCoordinator(scanQRCodeCoordinator)

        scanQRCodeCoordinator.start(fromSource: source, clipboardString: clipboardString)
    }
}

extension QRCodeResolutionCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        delegate?.didCancel(in: self)
    }

    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator) {
        guard !skipResolvedCodes else { return }

        skipResolvedCodes = true
        resolveScanResult(result, decodedValue: decodedValue)
    }

    private func availableActions(forContract contract: AlphaWallet.Address) async -> [ScanQRCodeAction] {
        switch usage {
        case .all(let tokensDataStore, _):
            let isTokenFound = await tokensDataStore.token(for: contract, server: .main) != nil
            if isTokenFound {
                return [.sendToAddress, .watchWallet, .openInEtherscan]
            } else {
                return [.sendToAddress, .addCustomToken, .watchWallet, .openInEtherscan]
            }
        case .importWalletOnly:
            return [.watchWallet]
        }
    }

    private func resolveScanResult(_ string: String, decodedValue: QrCodeValue) {
        guard let delegate = delegate else { return }

        Task { @MainActor in
            infoLog("[QR Code] resolved: \(decodedValue)")

            switch decodedValue {
            case .addressOrEip681(let value):
                switch value {
                case .address(let contract):
                    guard supportedResolutions.contains(.address) else { return }
                    let actions = await availableActions(forContract: contract)
                    if actions.count == 1 {
                        delegate.coordinator(self, didResolve: .address(address: contract, action: actions[0]))
                    } else {
                        showDidScanWalletAddress(for: actions, completion: { action in
                            delegate.coordinator(self, didResolve: .address(address: contract, action: action))
                        }, cancelCompletion: {
                            self.skipResolvedCodes = false
                        })
                    }
                case .eip681(let protocolName, let address, let functionName, let params):
                    guard supportedResolutions.contains(.transactionType) else { return }
                    switch usage {
                    case .all(_, let sessionsProvider):
                        let resolver = Eip681UrlResolver(
                            sessionsProvider: sessionsProvider,
                            missingRPCServerStrategy: .fallbackToFirstMatching)

                        resolver.resolve(protocolName: protocolName, address: address, functionName: functionName, params: params)
                            .sink(receiveCompletion: { result in
                                guard case .failure(let error) = result else { return }
                                verboseLog("[Eip681UrlResolver] failure to resolve value from: \(decodedValue) with error: \(error)")
                            }, receiveValue: { result in
                                switch result {
                                case .transaction(let transactionType, let token):
                                    delegate.coordinator(self, didResolve: .transactionType(transactionType: transactionType, token: token))
                                case .address:
                                    break // Not possible here
                                }
                            })
                            .store(in: &cancellable)
                    case .importWalletOnly:
                        break
                    }
                }
            case .string(let value):
                guard supportedResolutions.contains(.string) else { return }
                delegate.coordinator(self, didResolve: .string(value: value))
            case .walletConnect(let url):
                guard supportedResolutions.contains(.walletConnectUrl) else { return }
                delegate.coordinator(self, didResolve: .walletConnectUrl(url: url))
            case .url(let url):
                guard supportedResolutions.contains(.url) else { return }
                showOpenURL(completion: {
                    delegate.coordinator(self, didResolve: .url(url: url))
                }, cancelCompletion: {
                    //NOTE: we need to reset flag to false to make sure that next detected QR code will be handled
                    self.skipResolvedCodes = false
                })
            case .json(let value):
                guard supportedResolutions.contains(.json) else { return }
                delegate.coordinator(self, didResolve: .json(json: value))
            case .privateKey(let value):
                guard supportedResolutions.contains(.privateKey) else { return }
                delegate.coordinator(self, didResolve: .privateKey(privateKey: value))
            case .seedPhase(let value):
                guard supportedResolutions.contains(.seedPhase) else { return }
                delegate.coordinator(self, didResolve: .seedPhase(seedPhase: value))
            case .attestation(let attestation):
                guard supportedResolutions.contains(.attestation) else { return }
                delegate.coordinator(self, didResolve: .attestation(attestation: attestation))
            }
        }
    }

    private func showDidScanWalletAddress(for actions: [ScanQRCodeAction],
                                          completion: @escaping (ScanQRCodeAction) -> Void,
                                          cancelCompletion: @escaping () -> Void) {

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

extension QRCodeResolutionCoordinator {
    enum SupportedQrCodeResolution: Int, CaseIterable {
        case address
        case transactionType
        case walletConnectUrl
        case string
        case url
        case json
        case seedPhase
        case privateKey
        case attestation

        static var jsonOrSeedPhraseResolution: Set<SupportedQrCodeResolution> {
            return [.address, .json, .seedPhase, .privateKey]
        }
    }
}
