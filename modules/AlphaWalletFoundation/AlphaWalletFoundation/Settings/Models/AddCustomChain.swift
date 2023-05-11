// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import Combine

public enum AddCustomChainError: Error {
    case cancelled
    case missingBlockchainExplorerUrl
    case invalidBlockchainExplorerUrl
    case noRpcNodeUrl
    case invalidChainId(String)
    case chainIdNotMatch(String, String)
    case unknown(Error)

    public init(error: Error) {
        if let e = error as? AddCustomChainError {
            self = e
        } else {
            self = .unknown(error)
        }
    }
}

private enum ResolveExplorerApiHostnameError: Error {
    case resolveExplorerApiHostnameFailure
}

public protocol AddCustomChainDelegate: AnyObject {
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain)
    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain)
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> AnyPublisher<Bool, Never>
    func notifyRpcURlHostnameFailure()
}

// TODO: Remove when other classes which implement AddCustomChainDelegate protocol add this function.
extension AddCustomChainDelegate {
    public func notifyRpcURlHostnameFailure() {
    }
}

//TODO The detection and tests for various URLs are async so the UI might appear to do nothing to user as it is happening
public class AddCustomChain {
    private typealias CheckBlockchainExplorerApiHostnamePublisher = AnyPublisher<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String), AddCustomChainError>
    public typealias CustomChainWithChainIdAndRPC = (customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)
    private var cancelable: AnyCancellable?
    private var customChain: WalletAddEthereumChainObject
    private let isTestnet: Bool
    private let restartHandler: RestartQueueHandler
    private let url: URL?
    private let operation: SaveOperationType
    private let chainNameFallback: String
    private let networking: AddCustomChainNetworking
    private let analytics: AnalyticsLogger
    private let networkService: NetworkService

    public weak var delegate: AddCustomChainDelegate?

    public init(_ customChain: WalletAddEthereumChainObject,
                isTestnet: Bool,
                restartHandler: RestartQueueHandler,
                url: URL?,
                operation: SaveOperationType,
                chainNameFallback: String,
                networkService: NetworkService,
                analytics: AnalyticsLogger) {

        self.networkService = networkService
        self.networking = AddCustomChainNetworking(networkService: networkService)
        self.customChain = customChain
        self.isTestnet = isTestnet
        self.restartHandler = restartHandler
        self.url = url
        self.operation = operation
        self.chainNameFallback = chainNameFallback
        self.analytics = analytics
    }

    public func run() {
        cancelable?.cancel()
        cancelable = functional
            .checkChainId(customChain)
            .flatMap { [chainNameFallback] customChain, chainId in
                self.checkAndDetectUrls(customChain, chainId: chainId, chainNameFallback: chainNameFallback)
                    .catch { error -> AnyPublisher<CustomChainWithChainIdAndRPC, AddCustomChainError> in
                        guard case .unknown(let e) = error, case ResolveExplorerApiHostnameError.resolveExplorerApiHostnameFailure = e else {
                            return .fail(error)
                        }
                        return self.requestToUseFailedExplorerHostname(customChain: customChain, chainId: chainId)
                    }
            }.flatMap { [networking] customChain, chainId, rpcUrl -> AnyPublisher<(chainId: Int, rpcUrl: String, explorerType: RPCServer.EtherscanCompatibleType), AddCustomChainError> in
                self.customChain = customChain
                return networking.checkExplorerType(customChain)
                    .map { (chainId: chainId, rpcUrl: rpcUrl, explorerType: $0) }
                    .eraseToAnyPublisher()
            }.flatMap { chainId, rpcUrl, explorerType in
                self.handleOperation(self.customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: explorerType)
            }.ignoreOutput()
            .sink(receiveCompletion: { result in
                switch result {
                case .failure(let error):
                    switch error {
                    case .unknown(let e):
                        switch e {
                        case SessionTaskError.connectionError:
                            self.delegate?.notifyRpcURlHostnameFailure()
                        default:
                            self.delegate?.notifyAddCustomChainFailed(error: error, in: self)
                        }
                    case .cancelled:
                        return
                    case .missingBlockchainExplorerUrl, .invalidBlockchainExplorerUrl, .noRpcNodeUrl, .invalidChainId, .chainIdNotMatch:
                        self.delegate?.notifyAddCustomChainFailed(error: error, in: self)
                    }
                case .finished:
                    self.delegate?.notifyAddCustomChainQueuedSuccessfully(in: self)
                }
            }, receiveValue: { _ in })
    }

    private func requestToUseFailedExplorerHostname(customChain: WalletAddEthereumChainObject,
                                                    chainId: Int) -> AnyPublisher<CustomChainWithChainIdAndRPC, AddCustomChainError> {

        guard let delegate = self.delegate else {
            return .fail(AddCustomChainError.missingBlockchainExplorerUrl)
        }

        return delegate
            .notifyAddExplorerApiHostnameFailure(customChain: customChain, chainId: chainId)
            .tryMap { continueWithoutExplorerUrl -> CustomChainWithChainIdAndRPC in
                guard continueWithoutExplorerUrl else {
                    throw AddCustomChainError.cancelled
                }
                if let rpcUrl = customChain.rpcUrls?.first {
                    return (customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
                } else {
                    throw AddCustomChainError.missingBlockchainExplorerUrl
                }
            }.mapError { AddCustomChainError(error: $0) }
            .eraseToAnyPublisher()
    }

    private func handleOperation(_ customChain: WalletAddEthereumChainObject,
                                 chainId: Int,
                                 rpcUrl: String,
                                 etherscanCompatibleType: RPCServer.EtherscanCompatibleType) -> AnyPublisher<Void, AddCustomChainError> {

        switch operation {
        case .add:
            return self.queueAddCustomChain(customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType)
        case .edit(let originalRpc):
            return self.queueEditCustomChain(customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, originalRpc: originalRpc)
        }
    }

    private func queueAddCustomChain(_ customChain: WalletAddEthereumChainObject,
                                     chainId: Int,
                                     rpcUrl: String,
                                     etherscanCompatibleType: RPCServer.EtherscanCompatibleType) -> AnyPublisher<Void, AddCustomChainError> {

        AnyPublisher<Void, AddCustomChainError>.create { [url, isTestnet, restartHandler, chainNameFallback] seal in
            let customRpc = CustomRPC(
                customChain: customChain,
                chainId: chainId,
                rpcUrl: rpcUrl,
                etherscanCompatibleType: etherscanCompatibleType,
                isTestnet: isTestnet,
                chainNameFallback: chainNameFallback)

            let server = RPCServer.custom(customRpc)
            restartHandler.add(.addServer(customRpc))
            restartHandler.add(.enableServer(server))
            restartHandler.add(.switchDappServer(server: server))
            if let url = url {
                restartHandler.add(.loadUrlInDappBrowser(url))
            }
            seal.send(())
            seal.send(completion: .finished)

            return AnyCancellable { }
        }
    }

    private func queueEditCustomChain(_ customChain: WalletAddEthereumChainObject,
                                      chainId: Int,
                                      rpcUrl: String,
                                      etherscanCompatibleType: RPCServer.EtherscanCompatibleType,
                                      originalRpc: CustomRPC) -> AnyPublisher<Void, AddCustomChainError> {

        AnyPublisher<Void, AddCustomChainError>.create { [url, isTestnet, restartHandler, chainNameFallback] seal in
            let newCustomRpc = CustomRPC(
                customChain: customChain,
                chainId: chainId,
                rpcUrl: rpcUrl,
                etherscanCompatibleType: etherscanCompatibleType,
                isTestnet: isTestnet,
                chainNameFallback: chainNameFallback)

            let server = RPCServer.custom(newCustomRpc)
            restartHandler.add(.editServer(original: originalRpc, edited: newCustomRpc))
            restartHandler.add(.switchDappServer(server: server))
            if let url = url {
                restartHandler.add(.loadUrlInDappBrowser(url))
            }

            seal.send(())
            seal.send(completion: .finished)

            return AnyCancellable { }
        }
    }

    private func checkAndDetectUrls(_ customChain: WalletAddEthereumChainObject,
                                    chainId: Int,
                                    chainNameFallback: String) -> CheckBlockchainExplorerApiHostnamePublisher {

        //We need a check that the url is a valid URL (especially because it might contain markers like `${INFURA_API_KEY}` and `${ALCHEMY_API_KEY}` which we don't support. We can't support Infura keys because if we don't already support this chain in the app, then it must not have been enabled for our Infura account so it wouldn't work anyway.)
        guard let rpcUrl = customChain.rpcUrls?.first(where: { URL(string: $0) != nil }) else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            return .fail(AddCustomChainError.noRpcNodeUrl)
        }

        return checkRpcServer(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, chainNameFallback: chainNameFallback)
            .flatMap { chainId, rpcUrl in self.checkBlockchainExplorerApiHostname(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl) }
            .eraseToAnyPublisher()
    }

    private func checkRpcServer(customChain: WalletAddEthereumChainObject,
                                chainId: Int,
                                rpcUrl: String,
                                chainNameFallback: String) -> AnyPublisher<(chainId: Int, rpcUrl: String), AddCustomChainError> {

        guard let url = URL(string: rpcUrl) else { return .fail(AddCustomChainError.noRpcNodeUrl) }

        //Whether the explorer API endpoint is Etherscan or blockscout or testnet or not doesn't matter here
        let customRpc = CustomRPC(
            customChain: customChain,
            chainId: chainId,
            rpcUrl: rpcUrl,
            etherscanCompatibleType: .unknown,
            isTestnet: false,
            chainNameFallback: chainNameFallback)

        let server = RPCServer.custom(customRpc)
        let provider = RpcBlockchainProvider(
            server: server,
            analytics: analytics,
            params: .defaultParams(for: server))

        return provider.getChainId()
            .mapError { AddCustomChainError.unknown($0) }
            .tryMap { retrievedChainId in
                if retrievedChainId == chainId {
                    return (chainId: chainId, rpcUrl: rpcUrl)
                } else {
                    throw AddCustomChainError.chainIdNotMatch(String(retrievedChainId), customChain.chainId)
                }
            }.mapError { AddCustomChainError(error: $0) }
            .eraseToAnyPublisher()
    }

    private func checkBlockchainExplorerApiHostname(customChain: WalletAddEthereumChainObject,
                                                    chainId: Int,
                                                    rpcUrl: String) -> CheckBlockchainExplorerApiHostnamePublisher {

        guard let urlString = customChain.blockExplorerUrls?.first else {
            return .fail(AddCustomChainError.missingBlockchainExplorerUrl)
        }

        return networking
            .figureOutHostname(urlString.url)
            .map { newUrlString in
                if urlString.url == newUrlString {
                    return (customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
                } else {
                    var updatedCustomChain = customChain
                    updatedCustomChain.blockExplorerUrls = [.init(name: "", url: newUrlString)]
                    return (customChain: updatedCustomChain, chainId: chainId, rpcUrl: rpcUrl)
                }
            }.catch { _ -> CheckBlockchainExplorerApiHostnamePublisher in
                return .fail(AddCustomChainError.unknown(ResolveExplorerApiHostnameError.resolveExplorerApiHostnameFailure))
            }.eraseToAnyPublisher()
    }
}

extension AddCustomChain {
    public enum functional {
    }
}

//Experimental. Having some of the logic in barely-functional style. Most importantly, immutable. Static functions in an inner class enforce that state of value-type arguments are not modified, but it's still possible to modify reference-typed arguments. For now, avoid those. Inner class is required instead of a `fileprivate` class because one of the value they provide is being easier to test, so they must be accessible from the testsuite
extension AddCustomChain.functional {
    public static func checkChainId(_ customChain: WalletAddEthereumChainObject) -> AnyPublisher<(customChain: WalletAddEthereumChainObject, chainId: Int), AddCustomChainError> {
        guard let chainId = Int(chainId0xString: customChain.chainId) else {
            return .fail(AddCustomChainError.invalidChainId(customChain.chainId))
        }
        return .just((customChain: customChain, chainId: chainId))
    }
}
