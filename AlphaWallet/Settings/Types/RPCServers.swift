// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import web3swift
import BigInt
import TrustKeystore

enum RPCServer: Hashable {
    case main
    case kovan
    case ropsten
    case rinkeby
    case poa
    case sokol
    case classic
    case callisto
    case xDai
    case custom(CustomRPC)

    var chainID: Int {
        switch self {
        case .main: return 1
        case .kovan: return 42
        case .ropsten: return 3
        case .rinkeby: return 4
        case .poa: return 99
        case .sokol: return 77
        case .classic: return 61
        case .callisto: return 104729
        case .xDai: return 100
        case .custom(let custom):
            return custom.chainID
        }
    }

    var name: String {
        switch self {
        case .main: return "Ethereum"
        case .kovan: return "Kovan"
        case .ropsten: return "Ropsten"
        case .rinkeby: return "Rinkeby"
        case .poa: return "POA Network"
        case .sokol: return "Sokol"
        case .classic: return "Ethereum Classic"
        case .callisto: return "Callisto"
        case .xDai: return "xDai"
        case .custom(let custom):
            return custom.name
        }
    }

    var getEtherscanURL: String {
        switch self {
        case .main: return Constants.mainnetEtherscanAPI
        case .ropsten: return Constants.ropstenEtherscanAPI
        case .rinkeby: return Constants.rinkebyEtherscanAPI
        case .kovan: return Constants.kovanEtherscanAPI
        case .poa: return Constants.mainnetEtherscanAPI
        case .sokol: return Constants.mainnetEtherscanAPI
        case .classic: return Constants.mainnetEtherscanAPI
        case .callisto: return Constants.mainnetEtherscanAPI
        case .xDai: return Constants.xDaiAPI
        case .custom: return Constants.mainnetEtherscanAPI
        }
    }

    var etherscanContractDetailsWebPageURL: String {
        switch self {
        case .main: return Constants.mainnetEtherscanContractDetailsWebPageURL
        case .ropsten: return Constants.ropstenEtherscanContractDetailsWebPageURL
        case .rinkeby: return Constants.rinkebyEtherscanContractDetailsWebPageURL
        case .kovan: return Constants.kovanEtherscanContractDetailsWebPageURL
        case .xDai: return Constants.xDaiContractPage
        case .poa, .sokol, .classic, .callisto, .custom: return Constants.mainnetEtherscanContractDetailsWebPageURL
        }
    }

    func etherscanAPIURLForTransactionList(for address: String) -> URL {
        return URL(string: getEtherscanURL + address)!
    }

    func etherscanContractDetailsWebPageURL(for address: String) -> URL {
        return URL(string: etherscanContractDetailsWebPageURL + address)!
    }

    var priceID: Address {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .sokol, .custom, .xDai:
            return Address(string: "0x000000000000000000000000000000000000003c")!
        case .poa:
            return Address(string: "0x00000000000000000000000000000000000000AC")!
        case .classic:
            return Address(string: "0x000000000000000000000000000000000000003D")!
        case .callisto:
            return Address(string: "0x0000000000000000000000000000000000000334")!
        }
    }

    var displayName: String {
        if isTestNetwork {
            return "\(name) (\(R.string.localizable.settingsNetworkTestLabelTitle()))"
        } else {
            return name
        }
    }

    var isTestNetwork: Bool {
        switch self {
        case .main, .poa, .classic, .callisto, .custom, .xDai: return false
        case .kovan, .ropsten, .rinkeby, .sokol: return true
        }
    }

    var symbol: String {
        switch self {
        case .main: return "ETH"
        case .classic: return "ETC"
        case .callisto: return "CLO"
        case .kovan, .ropsten, .rinkeby: return "ETH"
        case .poa, .sokol: return "POA"
        case .xDai: return "xDai"
        case .custom(let custom):
            return custom.symbol
        }
    }

    var decimals: Int {
        return 18
    }

    var web3Network: Networks {
        switch self {
        case .main: return .Mainnet
        case .kovan: return .Kovan
        case .ropsten: return .Ropsten
        case .rinkeby: return .Rinkeby
        case .poa, .sokol, .classic, .callisto, .xDai:
            return .Custom(networkID: BigUInt(chainID))
        case .custom:
            return .Custom(networkID: BigUInt(chainID))
        }
    }

    init(name: String) {
        self = {
            switch name {
            case RPCServer.main.name: return .main
            case RPCServer.classic.name: return .classic
            case RPCServer.callisto.name: return .callisto
            case RPCServer.kovan.name: return .kovan
            case RPCServer.ropsten.name: return .ropsten
            case RPCServer.rinkeby.name: return .rinkeby
            case RPCServer.poa.name: return .poa
            case RPCServer.sokol.name: return .sokol
            case RPCServer.xDai.name: return .xDai
            default: return .main
            }
        }()
    }

    init(chainID: Int) {
        self = {
            switch chainID {
            case RPCServer.main.chainID: return .main
            case RPCServer.classic.chainID: return .classic
            case RPCServer.callisto.chainID: return .callisto
            case RPCServer.kovan.chainID: return .kovan
            case RPCServer.ropsten.chainID: return .ropsten
            case RPCServer.rinkeby.chainID: return .rinkeby
            case RPCServer.poa.chainID: return .poa
            case RPCServer.sokol.chainID: return .sokol
            case RPCServer.xDai.chainID: return .xDai
            default: return .main
            }
        }()
    }
}
