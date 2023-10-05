// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import AlphaWalletABI
import AlphaWalletCore

public struct DappCommand: Decodable {
    public let name: Method
    public let id: Int
    public let object: [String: DappCommandObjectValue]
}

//The optional values help us to filter out those that don't parse. Eg. we don't expect that key-value pair — maybe the dapp might include those for testing, or maybe we don't make use them yet
public struct DappCommandWithOptionalObjectValues: Decodable {
    public let name: Method
    public let id: Int
    public let object: [String: DappCommandObjectValue?]

    public var toCommand: DappCommand {
        return DappCommand(name: name, id: id, object: object.compactMapValues { $0 })
    }
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
    case signEip712v3And4(Data)
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
        case .signEip712v3And4(let data):
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

    public struct ExplorerUrl: Decodable {
        let name: String
        public let url: String

        enum CodingKeys: CodingKey {
            case name
            case url
        }

        public init(name: String, url: String) {
            self.url = url
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            do {
                let container = try decoder.singleValueContainer()
                url = try container.decode(String.self)
                name = String()
            } catch {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                url = try container.decode(String.self, forKey: .url)
            }
        }
    }

    public let nativeCurrency: NativeCurrency?
    public var blockExplorerUrls: [ExplorerUrl]?
    public let chainName: String?
    public let chainId: String
    public let rpcUrls: [String]?

    public var server: RPCServer? {
        return Int(chainId0xString: chainId).flatMap { RPCServer(chainIdOptional: $0) }
    }

    public init(nativeCurrency: NativeCurrency?, blockExplorerUrls: [ExplorerUrl]?, chainName: String?, chainId: String, rpcUrls: [String]?) {
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
        self.init(chainID: chainId, nativeCryptoTokenName: customChain.nativeCurrency?.name, chainName: customChain.chainName ?? chainNameFallback, symbol: customChain.nativeCurrency?.symbol, rpcEndpoint: rpcUrl, explorerEndpoint: customChain.blockExplorerUrls?.first?.url, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet)
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
