// Copyright DApps Platform Inc. All rights reserved.

import Foundation

struct DappCommand: Decodable {
    let name: Method
    let id: Int
    let object: [String: DappCommandObjectValue]
}

//TODO may not be the best name (contrast with the counterpart DappCommand), but let's see what happens after we add a few more cases to the `Method` enum
struct WalletCommand: Decodable {
    enum Method: String, Decodable {
        case walletAddEthereumChain

        init?(string: String) {
            if let s = Method(rawValue: string) {
                self = s
            } else {
                return nil
            }
        }
    }

    let name: Method
    let id: Int
    let object: WalletAddEthereumChainObject
}

enum DappOrWalletCommand {
    case eth(DappCommand)
    //TODO we'll have to see how to expand this, do we add more cases when there are more walletXXX object types, or do we generalize them?
    case walletAddEthereumChain(WalletCommand)

    var id: Int {
        switch self {
        case .eth(let command):
            return command.id
        case .walletAddEthereumChain(let command):
            return command.id
        }
    }
}

struct DappCallback {
    let id: Int
    let value: DappCallbackValue
}

enum DappCallbackValue {
    case signTransaction(Data)
    case sentTransaction(Data)
    case signMessage(Data)
    case signPersonalMessage(Data)
    case signTypedMessage(Data)
    case signTypedMessageV3(Data)
    case ethCall(String)
    case walletAddEthereumChain

    var object: String {
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
        }
    }
}

struct DappCommandObjectValue: Decodable {
    var value: String = ""
    var eip712PreV3Array: [EthTypedData] = []
    let eip712v3And4Data: EIP712TypedData?

    init(from coder: Decoder) throws {
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

struct WalletAddEthereumChainObject: Decodable {
    struct NativeCurrency: Decodable {
        let name: String
        let symbol: String
        let decimals: Int
    }

    let nativeCurrency: NativeCurrency?
    var blockExplorerUrls: [String]?
    let chainName: String?
    let chainId: String
    let rpcUrls: [String]?
}

extension CustomRPC {
    init(customChain: WalletAddEthereumChainObject, chainId: Int, rpcUrl: String, etherscanCompatibleType: RPCServer.EtherscanCompatibleType, isTestnet: Bool) {
        self.init(chainID: chainId, nativeCryptoTokenName: customChain.nativeCurrency?.name, chainName: customChain.chainName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customChain.nativeCurrency?.symbol, rpcEndpoint: rpcUrl, explorerEndpoint: customChain.blockExplorerUrls?.first, etherscanCompatibleType: etherscanCompatibleType, isTestnet: isTestnet)
    }
}