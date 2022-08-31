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
        case all(tokensService: TokenProvidable & TokenAddable, assetDefinitionStore: AssetDefinitionStore)
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
    private let analytics: AnalyticsLogger
    var coordinators: [Coordinator] = []
    weak var delegate: QRCodeResolutionCoordinatorDelegate?

    init(config: Config, coordinator: ScanQRCodeCoordinator, usage: Usage, account: Wallet, analytics: AnalyticsLogger) {
        self.config = config
        self.usage = usage
        self.scanQRCodeCoordinator = coordinator
        self.account = account
        self.analytics = analytics
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
        case .all(let service, _):
            let isTokenFound = service.token(for: contract, server: .main) != nil
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
            case .eip681(let protocolName, let address, let function, let params):
                let data = CheckEIP681Params(protocolName: protocolName, address: address, functionName: function, params: params)
                switch usage {
                case .all(let tokensService, let assetDefinitionStore):
                    firstly {
                        checkEIP681(data, tokensService: tokensService, assetDefinitionStore: assetDefinitionStore)
                    }.done { result in
                        delegate.coordinator(self, didResolveTransactionType: result.transactionType, token: result.token)
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

    private struct CheckEIP681Params {
        let protocolName: String
        let address: AddressOrEnsName
        let functionName: String?
        let params: [String: String]
    }

    private func checkEIP681(_ params: CheckEIP681Params, tokensService: TokenProvidable & TokenAddable, assetDefinitionStore: AssetDefinitionStore) -> Promise<(transactionType: TransactionType, token: Token)> {
        let analytics = self.analytics
        return Eip681Parser(protocolName: params.protocolName, address: params.address, functionName: params.functionName, params: params.params).parse().then { result -> Promise<(transactionType: TransactionType, token: Token)> in
            guard let (contract: contract, customServer, recipient, maybeScientificAmountString) = result.parameters else { return .init(error: CheckEIP681Error.parameterInvalid) }
            guard let server = self.serverFromEip681LinkOrDefault(customServer) else { return .init(error: CheckEIP681Error.missingRpcServer) }
            if let token = tokensService.token(for: contract, server: server) {
                let amount = maybeScientificAmountString.scientificAmountToBigInt.flatMap {
                    EtherNumberFormatter.full.string(from: $0, decimals: token.decimals)
                }
                let transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
                return .value((transactionType, token))
            } else {
                return Promise { resolver in
                    ContractDataDetector(address: contract, account: self.account, server: server, assetDefinitionStore: assetDefinitionStore, analytics: analytics).fetch { result in
                        switch result {
                        case .name, .symbol, .balance, .decimals, .nonFungibleTokenComplete, .delegateTokenComplete, .failed:
                            resolver.reject(CheckEIP681Error.contractInvalid)
                        case .fungibleTokenComplete(let name, let symbol, let decimals):
                            let token = tokensService.addCustom(tokens: [.init(
                                contract: contract,
                                server: server,
                                name: name,
                                symbol: symbol,
                                decimals: Int(decimals),
                                type: .erc20,
                                balance: .balance(["0"])
                            )], shouldUpdateBalance: true)[0]
                            guard let token = tokensService.token(for: token.contractAddress, server: token.server) else { return }
                            let amount = maybeScientificAmountString.scientificAmountToBigInt.flatMap {
                                EtherNumberFormatter.full.string(from: $0, decimals: token.decimals)
                            }
                            let transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)

                            resolver.fulfill((transactionType, token))
                        }
                    }
                }
            }
        }
    }

    private func serverFromEip681LinkOrDefault(_ serverInLink: RPCServer?) -> RPCServer? {
        if let serverInLink = serverInLink {
            return serverInLink
        }
        if config.enabledServers.count == 1 {
            //Specs https://eips.ethereum.org/EIPS/eip-681 says we should fallback to the current chainId, but since we support multiple chains at the same time, we only fallback if there is exactly 1 enabled network
            return config.enabledServers.first!
        }
        return nil
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
