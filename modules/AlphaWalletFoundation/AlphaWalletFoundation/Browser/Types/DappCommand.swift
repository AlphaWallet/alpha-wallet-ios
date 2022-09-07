// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public struct DappCommand: Decodable {
    public let name: Method
    public let id: Int
    public let object: [String: DappCommandObjectValue]
}

public struct AddCustomChainCommand: Decodable {
    //Single case enum just useful for validation
    public enum Method: String, Decodable {
        case walletAddEthereumChain

        public init?(string: String) {
            if let s = Method(rawValue: string) {
                self = s
            } else {
                return nil
            }
        }
    }

    public let name: Method
    public let id: Int
    public let object: WalletAddEthereumChainObject
}

public struct SwitchChainCommand: Decodable {
    //Single case enum just useful for validation
    public enum Method: String, Decodable {
        case walletSwitchEthereumChain

        public init?(string: String) {
            if let s = Method(rawValue: string) {
                self = s
            } else {
                return nil
            }
        }
    }

    public let name: Method
    public let id: Int
    public let object: WalletSwitchEthereumChainObject
}

public enum DappOrWalletCommand {
    case eth(DappCommand)
    case walletAddEthereumChain(AddCustomChainCommand)
    case walletSwitchEthereumChain(SwitchChainCommand)

    public var id: Int {
        switch self {
        case .eth(let command):
            return command.id
        case .walletAddEthereumChain(let command):
            return command.id
        case .walletSwitchEthereumChain(let command):
            return command.id
        }
    }
}

public struct DappCallback {
    public let id: Int
    public let value: DappCallbackValue

    public init(id: Int, value: DappCallbackValue) {
        self.id = id
        self.value = value
    }
}

public enum DappCallbackValue {
    case signTransaction(Data)
    case sentTransaction(Data)
    case signMessage(Data)
    case signPersonalMessage(Data)
    case signTypedMessage(Data)
    case signTypedMessageV3(Data)
    case ethCall(String)
    case walletAddEthereumChain
    case walletSwitchEthereumChain

    public var object: String {
        switch self {
        case .signTransaction(let data):
            return data.hexEncoded
        case .sentTransaction(let data):
            return data.hexEncoded
        case .signMessage(let data):
            return data.hexEncoded
        case .signPersonalMessage(let data):
            return data.hexEncoded
        case .signTypedMessage(let data):
            return data.hexEncoded
        case .signTypedMessageV3(let data):
            return data.hexEncoded
        case .ethCall(let value):
            return value
        case .walletAddEthereumChain:
            return ""
        case .walletSwitchEthereumChain:
            return ""
        }
    }
}

public struct DappCommandObjectValue: Decodable {
    public var value: String = ""
    public var eip712PreV3Array: [EthTypedData] = []
    public let eip712v3And4Data: EIP712TypedData?

    public init(from coder: Decoder) throws {
        let container = try coder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
            eip712v3And4Data = nil
        } else if let stringValue = try? container.decode(String.self) {
            if let data = stringValue.data(using: .utf8), let object = try? JSONDecoder().decode(EIP712TypedData.self, from: data) {
                value = ""
                eip712v3And4Data = object
            } else {
                value = stringValue
                eip712v3And4Data = nil
            }
        } else if let boolValue = try? container.decode(Bool.self) {
            //TODO not sure if we actually need the handle bools here. But just to make sure an additional Bool doesn't break the creation of `[String: DappCommandObjectValue]` and hence `DappCommand`, we convert it to a `String`
            value = String(boolValue)
            eip712v3And4Data = nil
        } else {
            var arrayContainer = try coder.unkeyedContainer()
            while !arrayContainer.isAtEnd {
                eip712PreV3Array.append(try arrayContainer.decode(EthTypedData.self))
            }
            eip712v3And4Data = nil
        }
    }
}

public struct WalletAddEthereumChainObject: Decodable, CustomStringConvertible {
    public struct NativeCurrency: Decodable, CustomStringConvertible {
        public let name: String
        public let symbol: String
        public let decimals: Int

        public var description: String {
            return "{name: \(name), symbol: \(symbol), decimals:\(decimals) }"
        }
        public init(name: String, symbol: String, decimals: Int) {
            self.name = name
            self.symbol = symbol
            self.decimals = decimals
        }
    }

    public let nativeCurrency: NativeCurrency?
    public var blockExplorerUrls: [String]?
    public let chainName: String?
    public let chainId: String
    public let rpcUrls: [String]?

    public init(nativeCurrency: NativeCurrency?, blockExplorerUrls: [String]?, chainName: String?, chainId: String, rpcUrls: [String]?) {
        self.nativeCurrency = nativeCurrency
        self.blockExplorerUrls = blockExplorerUrls
        self.chainName = chainName
        self.chainId = chainId
        self.rpcUrls = rpcUrls
    }

    public var description: String {
        return "{ blockExplorerUrls: \(String(describing: blockExplorerUrls)), chainName: \(String(describing: chainName)), chainId: \(String(describing: chainId)), rpcUrls: \(String(describing: rpcUrls)), nativeCurrency: \(String(describing: nativeCurrency)) }"
    }
}

extension CustomRPC {
    public init(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, etherscanCompatibleType: RPCServer.EtherscanCompatibleType, isTestnet: Bool, chainNameFallback: String) {
        self.init(chainID: chainId, nativeCryptoTokenName: customChain.nativeCurrency?.name, chainName: customChain.chainName ?? chainNameFallback, symbol: customChain.nativeCurrency?.symbol, rpcEndpoint: rpcUrl, explorerEndpoint: customChain.blockExplorerUrls?.first, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet)
    }
}

public struct WalletSwitchEthereumChainObject: Decodable, CustomStringConvertible {
    public let chainId: String
    public var server: RPCServer? {
        return Int(chainId0xString: chainId).flatMap { RPCServer(chainIdOptional: $0) }
    }

    public var description: String {
        return "chainId: \(chainId)"
    }
}
