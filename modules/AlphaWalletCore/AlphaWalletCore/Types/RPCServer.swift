// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public enum RPCServer: Hashable, CaseIterable {
    public enum EtherscanCompatibleType: String, Codable {
        case etherscan
        case blockscout
        case unknown
    }

    case main
    case classic
    //As of 20210601, `.callisto` doesn't eth_blockNumber because their endpoint requires including `"params": []` in the payload even if it's empty and we don't.
    //As of 20210601, `.callisto` doesn't support eth_call according to https://testnet-explorer.callisto.network/eth-rpc-api-docs
    case callisto
    case xDai
    case goerli
    case binance_smart_chain
    case binance_smart_chain_testnet
    case heco
    case heco_testnet
    case fantom
    case fantom_testnet
    case avalanche
    case avalanche_testnet
    case polygon
    case mumbai_testnet
    case optimistic
    case cronosMainnet
    case cronosTestnet
    case custom(CustomRPC)
    case arbitrum
    case palm
    case palmTestnet
    case klaytnCypress
    case klaytnBaobabTestnet
    case ioTeX
    case ioTeXTestnet
    case optimismGoerli
    case arbitrumGoerli
    case okx
    case sepolia

    public var chainID: Int {
        switch self {
        case .main: return 1
        case .classic: return 61
        case .callisto: return 104729
        case .xDai: return 100
        case .goerli: return 5
        case .binance_smart_chain: return 56
        case .binance_smart_chain_testnet: return 97
        case .heco: return 128
        case .heco_testnet: return 256
        case .custom(let custom): return custom.chainID
        case .fantom: return 250
        case .fantom_testnet: return 0xfa2
        case .avalanche: return 0xa86a
        case .avalanche_testnet: return 0xa869
        case .polygon: return 137
        case .mumbai_testnet: return 80001
        case .optimistic: return 10
        case .cronosTestnet: return 338
        case .cronosMainnet: return 25
        case .arbitrum: return 42161
        case .palm: return 11297108109
        case .palmTestnet: return 11297108099
        case .klaytnCypress: return 8217
        case .klaytnBaobabTestnet: return 1001
        case .ioTeX: return 4689
        case .ioTeXTestnet: return 4690
        case .optimismGoerli: return 420
        case .arbitrumGoerli: return 421613
        case .okx: return 66
        case .sepolia: return 11155111
        }
    }

    //We'll have to manually new cases here
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    public static var allCases: [RPCServer] {
        return [
            .main,
            .classic,
            .xDai,
            .goerli,
            .binance_smart_chain_testnet,
            .binance_smart_chain,
            .heco,
            //.heco_testnet, TODO: Enable if find another working rpc url
            .fantom,
            .fantom_testnet,
            .avalanche,
            .avalanche_testnet,
            .polygon,
            .callisto,
            .mumbai_testnet,
            .optimistic,
            .cronosMainnet,
            .cronosTestnet,
            .arbitrum,
            .klaytnCypress,
            .klaytnBaobabTestnet,
            .palm,
            .palmTestnet,
            //.ioTeX, //TODO: Disabled as non in Phase 1 anymore, need to take a look on transactions, native balances
            //.ioTeXTestnet
            .optimismGoerli,
            .arbitrumGoerli,
            .okx,
            .sepolia,
        ]
    }

    public private(set) static var customServers: [Self] = customRpcs.map { RPCServer.custom($0) }

    public static var customRpcs: [CustomRPC] = RPCServer.convertJsonToCustomRpcs(Config().customRpcServersJson) {
        didSet {
            if let data = try? JSONEncoder().encode(customRpcs), let json = String(data: data, encoding: .utf8) {
                var c = Config()
                c.customRpcServersJson = json
                customServers = customRpcs.map { RPCServer.custom($0) }
            } else {
                //no-op
            }
        }
    }

    public static var availableServers: [RPCServer] {
        allCases + Self.customServers
    }

    public init(chainID: Int) {
        //TODO defaulting to .main is bad
        self = Self.availableServers.first { $0.chainID == chainID } ?? .main
    }

    private static func convertJsonToCustomRpcs(_ json: String?) -> [CustomRPC] {
        if let json = json {
            let data = Data(json.utf8)
            if let servers = try? JSONDecoder().decode([CustomRPC].self, from: data) {
                return servers
            } else {
                return .init()
            }
        } else {
            return .init()
        }
    }
}

extension RPCServer: Codable {
    private enum Keys: String, CodingKey {
        case chainId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let chainId = try container.decode(Int.self, forKey: .chainId)
        self = .init(chainID: chainId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(chainID, forKey: .chainId)
    }
}

fileprivate class Config {
    struct Keys {
        static let customRpcServers = "customRpcServers"
    }

    public var customRpcServersJson: String? {
        get {
            let defaults = UserDefaults.standardOrForTests
            return defaults.string(forKey: Keys.customRpcServers)
        }
        set {
            let defaults = UserDefaults.standardOrForTests
            defaults.set(newValue, forKey: Keys.customRpcServers)
        }
    }
}
