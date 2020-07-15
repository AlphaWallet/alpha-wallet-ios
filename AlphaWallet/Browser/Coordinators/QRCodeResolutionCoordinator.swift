//
//  File.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.09.2020.
//

import Foundation
import BigInt
import PromiseKit

protocol QRCodeResolutionCoordinatorDelegate: class {
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveTransferType transferType: TransferType, token: TokenObject)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveWalletConnectURL url: WCURL)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveString value: String)
    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveURL url: URL)

    func didCancel(in coordinator: QRCodeResolutionCoordinator)
}

enum ScanQRCodeAction: CaseIterable {
    case sendToAddress
    case addCustomToken
    case watchWallet
    case openInEtherscan

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

typealias WCURL = String
private enum ScanQRCodeResolution {
    case value(value: QRCodeValue)
    case walletConnect(WCURL)
    case other(String)
    case url(URL)

    init(rawValue: String) {
        if let value = QRCodeValueParser.from(string: rawValue.trimmed) {
            self = .value(value: value)
        } else if rawValue.hasPrefix("wc:") {
            self = .walletConnect(rawValue)
        } else if let url = URL(string: rawValue) {
            self = .url(url)
        } else {
            self = .other(rawValue)
        }
    }
}

private enum CheckEIP681Error: Error {
    case configurationInvalid
    case contractInvalid
    case parameterInvalid
    case missingRpcServer
}

final class QRCodeResolutionCoordinator: Coordinator {

    private let tokensDatastores: [TokensDataStore]
    private let assetDefinitionStore: AssetDefinitionStore
    private var skipResolvedCodes: Bool = false
    private var navigationController: UINavigationController {
        return scanQRCodeCoordinator.navigationController
    }
    private let scanQRCodeCoordinator: ScanQRCodeCoordinator
    private var rpcServer: RPCServer {
        return Config().server
    }
    var coordinators: [Coordinator] = []
    weak var delegate: QRCodeResolutionCoordinatorDelegate?

    init(coordinator: ScanQRCodeCoordinator, tokensDatastores: [TokensDataStore], assetDefinitionStore: AssetDefinitionStore) {
        self.tokensDatastores = tokensDatastores
        self.scanQRCodeCoordinator = coordinator
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        scanQRCodeCoordinator.delegate = self
        addCoordinator(scanQRCodeCoordinator)

        scanQRCodeCoordinator.start()
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

    private func stopScannerAndDissmiss(completion: @escaping () -> Void) {
        scanQRCodeCoordinator.stopScannerAndDissmiss(completion: completion)
    }

    private func resolveScanResult(_ rawValue: String) {
        guard let delegate = delegate else { return }
        let rpcServer = self.rpcServer

        switch ScanQRCodeResolution(rawValue: rawValue) {
        case .value(let value):
            switch value {
            case .address(let contract):
                let actions: [ScanQRCodeAction]
                //NOTE: or maybe we need pass though all servers?
                guard let tokensDatastore = tokensDatastores.first(where: { $0.server == rpcServer }) else { return }

                //I guess if we have token, we shouldn't be able to send to it, or we should?
                if tokensDatastore.token(forContract: contract) != nil {
                    actions = [.sendToAddress, .watchWallet, .openInEtherscan]
                } else {
                    actions = [.sendToAddress, .addCustomToken, .watchWallet, .openInEtherscan]
                }

                showDidScanWalletAddress(for: actions, completion: { action in
                    self.stopScannerAndDissmiss {
                        delegate.coordinator(self, didResolveAddress: contract, action: action)
                    }
                }, cancelCompletion: {
                    self.skipResolvedCodes = false
                })

            case .eip681(let protocolName, let address, let function, let params):
                let data = CheckEIP681Params(protocolName: protocolName, address: address, functionName: function, params: params, rpcServer: rpcServer)

                self.stopScannerAndDissmiss {
                    self.checkEIP681(data).done { result in
                        delegate.coordinator(self, didResolveTransferType: result.transferType, token: result.token)
                    }.cauterize()
                }
            }
        case .other(let value):
            stopScannerAndDissmiss {
                delegate.coordinator(self, didResolveString: value)
            }
        case .walletConnect(let url):
            stopScannerAndDissmiss {
                delegate.coordinator(self, didResolveWalletConnectURL: url)
            }
        case .url(let url):
            showOpenURL(completion: {
                self.stopScannerAndDissmiss {
                    delegate.coordinator(self, didResolveURL: url)
                }
            }, cancelCompletion: {
                //NOTE: we need to reset flat to false to make shure that next detected QR code will be handled
                self.skipResolvedCodes = false
            })
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

        controller.makePresentationFullScreenForiOS13Migration()

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

        controller.makePresentationFullScreenForiOS13Migration()

        navigationController.present(controller, animated: true)
    }

    private struct CheckEIP681Params {
        let protocolName: String
        let address: AddressOrEnsName
        let functionName: String?
        let params: [String: String]
        let rpcServer: RPCServer
    }

    private func checkEIP681(_ params: CheckEIP681Params) -> Promise<(transferType: TransferType, token: TokenObject)> {
        return Eip681Parser(protocolName: params.protocolName, address: params.address, functionName: params.functionName, params: params.params).parse().then { result -> Promise<(transferType: TransferType, token: TokenObject)> in
            guard let (contract: contract, customServer, recipient, maybeScientificAmountString) = result.parameters else {
                return .init(error: CheckEIP681Error.parameterInvalid)
            }

            guard let storage = self.tokensDatastores.first(where: { $0.server == customServer ?? params.rpcServer }) else {
                return .init(error: CheckEIP681Error.missingRpcServer)
            }

            if let token = storage.token(forContract: contract) {
                let amount = maybeScientificAmountString.scientificAmountToBigInt.flatMap {
                    EtherNumberFormatter.full.string(from: $0, decimals: token.decimals)
                }

                let transferType = TransferType(token: token, recipient: recipient, amount: amount)

                return .value((transferType, token))
            } else {
                return Promise { resolver in
                    fetchContractDataFor(address: contract, storage: storage, assetDefinitionStore: self.assetDefinitionStore) { result in
                        switch result {
                        case .name, .symbol, .balance, .decimals, .nonFungibleTokenComplete, .delegateTokenComplete, .failed:
                            resolver.reject(CheckEIP681Error.contractInvalid)
                        case .fungibleTokenComplete(let name, let symbol, let decimals):
                            let token = storage.addCustom(token: .init(
                                contract: contract,
                                server: storage.server,
                                name: name,
                                symbol: symbol,
                                decimals: Int(decimals),
                                type: .erc20,
                                balance: ["0"]
                            ))
                            let amount = maybeScientificAmountString.scientificAmountToBigInt.flatMap {
                                EtherNumberFormatter.full.string(from: $0, decimals: token.decimals)
                            }
                            let transferType = TransferType(token: token, recipient: recipient, amount: amount)

                            resolver.fulfill((transferType, token))
                        }
                    }
                }
            }
        }
    }
}

private extension String {
    var scientificAmountToBigInt: BigInt? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.usesGroupingSeparator = false

        let amountString = numberFormatter.number(from: self).flatMap { numberFormatter.string(from: $0) }
        return amountString.flatMap { BigInt($0) }
    }
}
