// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

public enum AddCustomChainError: LocalizedError {
    case cancelled
    case missingBlockchainExplorerUrl
    case invalidBlockchainExplorerUrl
    case noRpcNodeUrl
    case invalidChainId(String)
    case chainIdNotMatch(String, String)
    case unknown(Error)
}

private enum ResolveExplorerApiHostnameError: Error {
    case resolveExplorerApiHostnameFailure
}

public protocol AddCustomChainDelegate: AnyObject {
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain)
    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain)
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool>
    func notifyRpcURlHostnameFailure()
}

// TODO: Remove when other classes which implement AddCustomChainDelegate protocol add this function.
extension AddCustomChainDelegate {
    public func notifyRpcURlHostnameFailure() {
    }
}

//TODO The detection and tests for various URLs are async so the UI might appear to do nothing to user as it is happening
public class AddCustomChain {
    private var customChain: WalletAddEthereumChainObject
    private let analytics: AnalyticsLogger
    private let isTestnet: Bool
    private let restartQueue: RestartTaskQueue
    private let url: URL?
    private let operation: SaveOperationType
    private let chainNameFallback: String

    public weak var delegate: AddCustomChainDelegate?

    public init(_ customChain: WalletAddEthereumChainObject, analytics: AnalyticsLogger, isTestnet: Bool, restartQueue: RestartTaskQueue, url: URL?, operation: SaveOperationType, chainNameFallback: String) {
        self.customChain = customChain
        self.analytics = analytics
        self.isTestnet = isTestnet
        self.restartQueue = restartQueue
        self.url = url
        self.operation = operation
        self.chainNameFallback = chainNameFallback
    }

    public typealias CustomChainWithChainIdAndRPC = (customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)
    public func run() {
        firstly {
            functional.checkChainId(customChain)
        }.then { customChain, chainId -> Promise<CustomChainWithChainIdAndRPC> in
            functional.checkAndDetectUrls(customChain, chainId: chainId, analytics: self.analytics, chainNameFallback: self.chainNameFallback).recover { e -> Promise<CustomChainWithChainIdAndRPC> in
                if case ResolveExplorerApiHostnameError.resolveExplorerApiHostnameFailure = e {
                    return self.requestToUseFailedExplorerHostname(customChain: customChain, chainId: chainId)
                } else {
                    throw e
                }
            }
        }.then { customChain, chainId, rpcUrl -> Promise<(chainId: Int, rpcUrl: String, explorerType: RPCServer.EtherscanCompatibleType)> in
            self.customChain = customChain
            return functional.checkExplorerType(customChain).map { (chainId: chainId, rpcUrl: rpcUrl, explorerType: $0) }
        }.then { chainId, rpcUrl, explorerType in
            self.handleOperation(self.customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: explorerType)
        }.done {
            self.delegate?.notifyAddCustomChainQueuedSuccessfully(in: self)
        }.catch {
            switch $0 {
            case SessionTaskError.connectionError:
                self.delegate?.notifyRpcURlHostnameFailure()
            case is AddCustomChainError:
                self.delegate?.notifyAddCustomChainFailed(error: ($0 as! AddCustomChainError), in: self)
            case PMKError.cancelled:
                return
            default:
                self.delegate?.notifyAddCustomChainFailed(error: .unknown($0), in: self)
            }
        }
    }

    private func requestToUseFailedExplorerHostname(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<CustomChainWithChainIdAndRPC> {
        guard let delegate = self.delegate else {
            return .init(error: AddCustomChainError.missingBlockchainExplorerUrl)
        }
        return delegate.notifyAddExplorerApiHostnameFailure(customChain: customChain, chainId: chainId).map { continueWithoutExplorerURL -> CustomChainWithChainIdAndRPC in
            guard continueWithoutExplorerURL else {
                throw PMKError.cancelled
            }
            if let rpcUrl = customChain.rpcUrls?.first {
                return (customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
            } else {
                throw AddCustomChainError.missingBlockchainExplorerUrl
            }
        }
    }

    private func handleOperation(_ customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, etherscanCompatibleType: RPCServer.EtherscanCompatibleType) -> Promise<Void> {
            switch operation {
            case .add:
                return self.queueAddCustomChain(customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType)
            case .edit(let originalRpc):
                return self.queueEditCustomChain(customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, originalRpc: originalRpc)
             }
    }

    private func queueAddCustomChain(_ customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, etherscanCompatibleType: RPCServer.EtherscanCompatibleType) -> Promise<Void> {
        Promise { seal in
            let customRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet, chainNameFallback: chainNameFallback)
            let server = RPCServer.custom(customRpc)
            restartQueue.add(.addServer(customRpc))
            restartQueue.add(.enableServer(server))
            restartQueue.add(.switchDappServer(server: server))
            if let url = url {
                restartQueue.add(.loadUrlInDappBrowser(url))
            }
            seal.fulfill(())
        }
    }

    private func queueEditCustomChain(_ customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, etherscanCompatibleType: RPCServer.EtherscanCompatibleType, originalRpc: CustomRPC) -> Promise<Void> {
        Promise { seal in
            let newCustomRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet, chainNameFallback: chainNameFallback)
            let server = RPCServer.custom(newCustomRpc)
            restartQueue.add(.editServer(original: originalRpc, edited: newCustomRpc))
            restartQueue.add(.switchDappServer(server: server))
            if let url = url {
                restartQueue.add(.loadUrlInDappBrowser(url))
            }
            seal.fulfill(())
        }
    }
}

extension AddCustomChain {
    public class functional {
    }
}

//Experimental. Having some of the logic in barely-functional style. Most importantly, immutable. Static functions in an inner class enforce that state of value-type arguments are not modified, but it's still possible to modify reference-typed arguments. For now, avoid those. Inner class is required instead of a `fileprivate` class because one of the value they provide is being easier to test, so they must be accessible from the testsuite
extension AddCustomChain.functional {
    public static func checkChainId(_ customChain: WalletAddEthereumChainObject) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int)> {
        guard let chainId = Int(chainId0xString: customChain.chainId) else {
            return Promise(error: AddCustomChainError.invalidChainId(customChain.chainId))
        }
        return .value((customChain: customChain, chainId: chainId))
    }

    public static func checkAndDetectUrls(_ customChain: WalletAddEthereumChainObject, chainId: Int, analytics: AnalyticsLogger, chainNameFallback: String) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)> {
        //We need a check that the url is a valid URL (especially because it might contain markers like `${INFURA_API_KEY}` and `${ALCHEMY_API_KEY}` which we don't support. We can't support Infura keys because if we don't already support this chain in the app, then it must not have been enabled for our Infura account so it wouldn't work anyway.)
        guard let rpcUrl = customChain.rpcUrls?.first(where: { URL(string: $0) != nil }) else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            return Promise(error: AddCustomChainError.noRpcNodeUrl)
        }
        return firstly {
            checkRpcServer(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, analytics: analytics, chainNameFallback: chainNameFallback)
        }.then { chainId, rpcUrl in
            checkBlockchainExplorerApiHostname(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
        }
    }
    private static func checkRpcServer(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, analytics: AnalyticsLogger, chainNameFallback: String) -> Promise<(chainId: Int, rpcUrl: String)> {
        //Whether the explorer API endpoint is Etherscan or blockscout or testnet or not doesn't matter here
        let customRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: .unknown, isTestnet: false, chainNameFallback: chainNameFallback)
        let server = RPCServer.custom(customRpc)
        let request = EthChainIdRequest()
        return firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
        }.map { result in
            if let retrievedChainId = Int(chainId0xString: result), retrievedChainId == chainId {
                return (chainId: chainId, rpcUrl: rpcUrl)
            } else {
                throw AddCustomChainError.chainIdNotMatch(result, customChain.chainId)
            }
        }
    }

    private static func checkBlockchainExplorerApiHostname(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)> {
        guard let urlString = customChain.blockExplorerUrls?.first else {
            return Promise(error: AddCustomChainError.missingBlockchainExplorerUrl)
        }
        return firstly {
            figureOutHostname(urlString)
        }.map { newUrlString in
            if urlString == newUrlString {
                return (customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
            } else {
                var updatedCustomChain = customChain
                updatedCustomChain.blockExplorerUrls = [newUrlString]
                return (customChain: updatedCustomChain, chainId: chainId, rpcUrl: rpcUrl)
            }
        }.recover { _ -> Guarantee<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)> in
            throw ResolveExplorerApiHostnameError.resolveExplorerApiHostnameFailure
        }
    }
    static func checkExplorerType(_ customChain: WalletAddEthereumChainObject) -> Promise<RPCServer.EtherscanCompatibleType> {
        guard let urlString = customChain.blockExplorerUrls?.first else {
            return .value(.unknown)
        }
        guard let url = EtherscanURLBuilder(host: urlString).buildWithTokennfttx() else {
            return .value(.unknown)
        }

        return firstly {
            Alamofire.request(url, method: .get).responseJSON()
        }.map { json, _ in
            if let json = json as? [String: Any] {
                if json["result"] is [String] {
                    return .etherscan
                } else {
                    return .blockscout
                }
            } else {
                return .unknown
            }
        }.recover { _ -> Guarantee<RPCServer.EtherscanCompatibleType> in
            return .value(.unknown)
        }
    }
    //Figure out if "api." prefix is needed
    private static func figureOutHostname(_ originalUrlString: String) -> Promise<String> {
        if let isPrefixedWithApiDot = URL(string: originalUrlString)?.host?.hasPrefix("api."), isPrefixedWithApiDot {
            return .value(originalUrlString)
        }
        //TODO is it necessary to check if already have https/http?
        let urlString = originalUrlString
                .replacingOccurrences(of: "https://", with: "https://api.")
                .replacingOccurrences(of: "http://", with: "http://api.")
        //Careful to use `action=tokentx` and not `action=tokennfttx` because only the former works with both Etherscan and Blockscout
        guard let url =  EtherscanURLBuilder(host: urlString).buildWithTokentx() else {
            return Promise(error: AddCustomChainError.invalidBlockchainExplorerUrl)
        }
        return firstly {
            isValidBlockchainExplorerApiRoot(url)
        }.map {
            urlString
        }.recover { error -> Promise<String> in
            //Careful to use `action=tokentx` and not `action=tokennfttx` because only the former works with both Etherscan and Blockscout
            guard let url = EtherscanURLBuilder(host: originalUrlString).buildWithTokentx() else {
                return Promise(error: AddCustomChainError.invalidBlockchainExplorerUrl)
            }

            return firstly {
                isValidBlockchainExplorerApiRoot(url)
            }.map {
                originalUrlString
            }
        }
    }
    private static func isValidBlockchainExplorerApiRoot(_ url: URL) -> Promise<Void> {
        firstly {
            Alamofire.request(url, method: .get).responseJSON()
        }.map { json, _ in
            if let json = json as? [String: Any] {
                if json["result"] is [Any] {
                    return
                } else {
                    throw AddCustomChainError.invalidBlockchainExplorerUrl
                }
            } else {
                throw AddCustomChainError.invalidBlockchainExplorerUrl
            }
        }
    }
}

private struct EtherscanURLBuilder {
    private let host: String

    init(host: String) {
        self.host = host
    }

    func build(parameters: [String: String]) -> URL? {
        guard var url = URL(string: host) else { return nil }
        url.appendPathComponent("api")

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        urlComponents.queryItems = parameters.map { key, value -> URLQueryItem in
            URLQueryItem(name: key, value: value)
        }

        return urlComponents.url
    }

    /// "\(urlString)/api?module=account&action=tokennfttx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
    func buildWithTokennfttx() -> URL? {
        build(parameters: EtherscanURLBuilder.withTokennfttxParameters)
    }

    /// "\(urlString)/api?module=account&action=tokentx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
    func buildWithTokentx() -> URL? {
        build(parameters: EtherscanURLBuilder.withTokentxParameters)
    }

    static var withTokennfttxParameters: [String: String] {
        return [
            "module": "account",
            "action": "tokennfttx",
            "address": "0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
        ]
    }

    static var withTokentxParameters: [String: String] {
        return [
            "module": "account",
            "action": "tokentx",
            "address": "0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
        ]
    }
}
