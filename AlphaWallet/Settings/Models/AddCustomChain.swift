// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

enum AddCustomChainError: Error {
    case cancelled
    case others(String)
    var message: String {
        switch self {
        case .cancelled:
            //This is the default behavior, just keep it
            return "\(self)"
        case .others(let message):
            return message
        }
    }
}

private enum ResolveExplorerApiHostnameError: Error {
    case resolveExplorerApiHostnameFailure
}

protocol AddCustomChainDelegate: AnyObject {
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain)
    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain)
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool>
    func notifyRpcURlHostnameFailure()
}

// TODO: Remove when other classes which implement AddCustomChainDelegate protocol add this function.
extension AddCustomChainDelegate {
    func notifyRpcURlHostnameFailure() {
    }
}

//TODO The detection and tests for various URLs are async so the UI might appear to do nothing to user as it is happening
class AddCustomChain {
    private var customChain: WalletAddEthereumChainObject
    private let isTestnet: Bool
    private let restartQueue: RestartTaskQueue
    private let url: URL?
    private let operation: SaveOperationType
    weak var delegate: AddCustomChainDelegate?
    init(_ customChain: WalletAddEthereumChainObject, isTestnet: Bool, restartQueue: RestartTaskQueue, url: URL?, operation: SaveOperationType) {
        self.customChain = customChain
        self.isTestnet = isTestnet
        self.restartQueue = restartQueue
        self.url = url
        self.operation = operation
    }

    typealias CustomChainWithChainIdAndRPC = (customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)
    func run() {
        firstly {
            functional.checkChainId(customChain)
        }.then { customChain, chainId -> Promise<CustomChainWithChainIdAndRPC> in
            functional.checkAndDetectUrls(customChain, chainId: chainId).recover { e -> Promise<CustomChainWithChainIdAndRPC> in
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
                self.delegate?.notifyAddCustomChainFailed(error: .others("\(R.string.localizable.addCustomChainErrorUnknown()) — \($0)"), in: self)
            }
        }
    }

    private func requestToUseFailedExplorerHostname(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<CustomChainWithChainIdAndRPC> {
        guard let delegate = self.delegate else {
            return .init(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorNoBlockchainExplorerUrl()))
        }
        return delegate.notifyAddExplorerApiHostnameFailure(customChain: customChain, chainId: chainId).map { continueWithoutExplorerURL -> CustomChainWithChainIdAndRPC in
            guard continueWithoutExplorerURL else {
                throw PMKError.cancelled
            }
            if let rpcUrl = customChain.rpcUrls?.first {
                return (customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
            } else {
                throw AddCustomChainError.others(R.string.localizable.addCustomChainErrorNoBlockchainExplorerUrl())
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
            let customRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet)
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
            let newCustomRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet)
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
    class functional {
    }
}

//Experimental. Having some of the logic in barely-functional style. Most importantly, immutable. Static functions in an inner class enforce that state of value-type arguments are not modified, but it's still possible to modify reference-typed arguments. For now, avoid those. Inner class is required instead of a `fileprivate` class because one of the value they provide is being easier to test, so they must be accessible from the testsuite
extension AddCustomChain.functional {
    static func checkChainId(_ customChain: WalletAddEthereumChainObject) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int)> {
        guard let chainId = Int(chainId0xString: customChain.chainId) else {
            return Promise(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId)))
        }
        return .value((customChain: customChain, chainId: chainId))
    }

    static func checkAndDetectUrls(_ customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)> {
        //We need a check that the url is a valid URL (especially because it might contain markers like `${INFURA_API_KEY}` and `${ALCHEMY_API_KEY}` which we don't support. We can't support Infura keys because if we don't already support this chain in the app, then it must not have been enabled for our Infura account so it wouldn't work anyway.)
        guard let rpcUrl = customChain.rpcUrls?.first(where: { URL(string: $0) != nil }) else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            return Promise(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorNoRpcNodeUrl()))
        }
        return firstly {
            checkRpcServer(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
        }.then { chainId, rpcUrl in
            checkBlockchainExplorerApiHostname(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl)
        }
    }
    private static func checkRpcServer(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String) -> Promise<(chainId: Int, rpcUrl: String)> {
        //Whether the explorer API endpoint is Etherscan or blockscout or testnet or not doesn't matter here
        let customRpc = CustomRPC(customChain: customChain, chainId: chainId, rpcUrl: rpcUrl, etherscanCompatibleType: .unknown, isTestnet: false)
        let server = RPCServer.custom(customRpc)
        let request = EthChainIdRequest()
        return firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)))
        }.map { result in
            if let retrievedChainId = Int(chainId0xString: result), retrievedChainId == chainId {
                return (chainId: chainId, rpcUrl: rpcUrl)
            } else {
                throw AddCustomChainError.others(R.string.localizable.addCustomChainErrorChainIdNotMatch(result, customChain.chainId))
            }
        }
    }

    private static func checkBlockchainExplorerApiHostname(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String) -> Promise<(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String)> {
        guard let urlString = customChain.blockExplorerUrls?.first else {
            return Promise(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorNoBlockchainExplorerUrl()))
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
        guard let url = URL(string: "\(urlString)/api?module=account&action=tokennfttx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3") else {
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
        guard let url = URL(string: "\(urlString)/api?module=account&action=tokentx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3") else {
            return Promise(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl()))
        }
        return firstly {
            isValidBlockchainExplorerApiRoot(url)
        }.map {
            urlString
        }.recover { error -> Promise<String> in
            //Careful to use `action=tokentx` and not `action=tokennfttx` because only the former works with both Etherscan and Blockscout
            guard let url = URL(string: "\(originalUrlString)/api?module=account&action=tokentx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3") else {
                return Promise(error: AddCustomChainError.others(R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl()))
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
                    throw AddCustomChainError.others(R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl())
                }
            } else {
                throw AddCustomChainError.others(R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl())
            }
        }
    }
}
