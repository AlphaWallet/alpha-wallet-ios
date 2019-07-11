// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import web3swift
import BigInt

enum RPCServer: Hashable, CaseIterable {
    case main
    case kovan
    case ropsten
    case rinkeby
    case poa
    case sokol
    case classic
    case callisto
    case xDai
    case goerli
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
        case .goerli: return 5
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
        case .goerli: return "Goerli"
        case .custom(let custom):
            return custom.name
        }
    }

    var isTestnet: Bool {
        switch self {
        case .xDai, .classic, .main, .poa, .callisto:
            return false
        default:
            return true
        }
    }

    var getEtherscanURL: String? {
        switch self {
        case .main: return Constants.mainnetEtherscanAPI
        case .ropsten: return Constants.ropstenEtherscanAPI
        case .rinkeby: return Constants.rinkebyEtherscanAPI
        case .kovan: return Constants.kovanEtherscanAPI
        case .poa: return Constants.poaNetworkCoreAPI
        case .sokol: return nil
        case .classic: return nil
        case .callisto: return nil
        case .goerli: return Constants.goerliEtherscanAPI
        case .xDai: return Constants.xDaiAPI
        case .custom: return nil
        }
    }

    //TODO fix up all the networks
    var getEtherscanURLERC20Events: String? {
        switch self {
        case .main: return Constants.mainnetEtherscanAPIErc20Events
        case .ropsten: return Constants.ropstenEtherscanAPIErc20Events
        case .rinkeby: return Constants.rinkebyEtherscanAPIErc20Events
        case .kovan: return Constants.kovanEtherscanAPIErc20Events
        case .poa: return Constants.poaNetworkCoreAPIErc20Events
        case .sokol: return nil
        case .classic: return nil
        case .callisto: return nil
        case .goerli: return Constants.goerliEtherscanAPIErc20Events
        case .xDai: return Constants.xDaiAPIErc20Events
        case .custom: return nil
        }
    }

    var etherscanContractDetailsWebPageURL: String {
        switch self {
        case .main: return Constants.mainnetEtherscanContractDetailsWebPageURL
        case .ropsten: return Constants.ropstenEtherscanContractDetailsWebPageURL
        case .rinkeby: return Constants.rinkebyEtherscanContractDetailsWebPageURL
        case .kovan: return Constants.kovanEtherscanContractDetailsWebPageURL
        case .xDai: return Constants.xDaiContractPage
        case .goerli: return Constants.goerliContractPage
        case .poa: return Constants.poaContractPage
        case .sokol: return Constants.sokolContractPage
        case .classic: return Constants.etcContractPage
        case .callisto: return Constants.callistoContractPage
        case .custom: return Constants.mainnetEtherscanContractDetailsWebPageURL
        }
    }

    func etherscanAPIURLForTransactionList(for address: AlphaWallet.Address) -> URL? {
        return getEtherscanURL.flatMap { URL(string: $0 + address.eip55String) }
    }

    func etherscanAPIURLForERC20TxList(for address: AlphaWallet.Address) -> URL? {
        return getEtherscanURLERC20Events.flatMap { URL(string: $0 + address.eip55String) }
    }

    func etherscanContractDetailsWebPageURL(for address: AlphaWallet.Address) -> URL {
        return URL(string: etherscanContractDetailsWebPageURL + address.eip55String)!
    }

    var priceID: AlphaWallet.Address {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .sokol, .custom, .xDai, .goerli:
            return AlphaWallet.Address(string: "0x000000000000000000000000000000000000003c")!
        case .poa:
            return AlphaWallet.Address(string: "0x00000000000000000000000000000000000000AC")!
        case .classic:
            return AlphaWallet.Address(string: "0x000000000000000000000000000000000000003D")!
        case .callisto:
            return AlphaWallet.Address(string: "0x0000000000000000000000000000000000000334")!
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
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli: return true
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
        case .goerli: return "ETH"
        case .custom(let custom):
            return custom.symbol
        }
    }

    var cryptoCurrencyName: String {
        switch self {
        case .main, .classic, .callisto, .kovan, .ropsten, .rinkeby, .poa, .sokol, .goerli, .custom:
            return "Ether"
        case .xDai:
            return "xDai"
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
        case .poa, .sokol, .classic, .callisto, .xDai, .goerli:
            return .Custom(networkID: BigUInt(chainID))
        case .custom:
            return .Custom(networkID: BigUInt(chainID))
        }
    }

    var magicLinkPrefix: URL {
        let urlString = "https://\(magicLinkHost)/"
        return URL(string: urlString)!
    }

    var magicLinkHost: String {
        switch self {
        case .main:
            return Constants.mainnetMagicLinkHost
        case .kovan:
            return Constants.kovanMagicLinkHost
        case .ropsten:
            return Constants.ropstenMagicLinkHost
        case .rinkeby:
            return Constants.rinkebyMagicLinkHost
        case .poa:
            return Constants.poaMagicLinkHost
        case .sokol:
            return Constants.sokolMagicLinkHost
        case .classic:
            return Constants.classicMagicLinkHost
        case .callisto:
            return Constants.callistoMagicLinkHost
        case .goerli:
            return Constants.goerliMagicLinkHost
        case .xDai:
            return Constants.xDaiMagicLinkHost
        case .custom:
            return Constants.customMagicLinkHost
        }
    }

    var rpcURL: URL {
        let urlString: String = {
            switch self {
            case .main: return "https://mainnet.infura.io/v3/da3717f25f824cc1baa32d812386d93f"
            case .classic: return "https://ethereumclassic.network"
            case .callisto: return "https://callisto.network/" //TODO Add endpoint
            case .kovan: return "https://kovan.infura.io/v3/da3717f25f824cc1baa32d812386d93f"
            case .ropsten: return "https://ropsten.infura.io/v3/da3717f25f824cc1baa32d812386d93f"
            case .rinkeby: return "https://rinkeby.infura.io/v3/da3717f25f824cc1baa32d812386d93f"
            case .poa: return "https://core.poa.network"
            case .sokol: return "https://sokol.poa.network"
            case .goerli: return "https://goerli.infura.io/v3/da3717f25f824cc1baa32d812386d93f"
            case .xDai: return "https://dai.poa.network"
            case .custom(let custom):
                return custom.endpoint
            }
        }()
        return URL(string: urlString)!
    }

    var transactionInfoEndpoints: URL {
        let urlString: String = {
            switch self {
            case .main: return "https://api.etherscan.io"
            case .classic: return "https://blockscout.com/etc/mainnet/api"
            case .callisto: return "https://callisto.trustwalletapp.com"
            case .kovan: return "https://api-kovan.etherscan.io"
            case .ropsten: return "https://api-ropsten.etherscan.io"
            case .rinkeby: return "https://api-rinkeby.etherscan.io"
            case .poa: return "https://blockscout.com/poa/core/api"
            case .xDai: return "https://blockscout.com/poa/dai/api"
            case .sokol: return "https://blockscout.com/poa/sokol/api"
            case .goerli: return "https://api-goerli.etherscan.io"
            case .custom:
                return "" // Enable? make optional
            }
        }()
        return URL(string: urlString)!
    }

    var ensRegistrarContract: AlphaWallet.Address {
        switch self {
        case .main: return Constants.ENSRegistrarAddress
        case .ropsten: return Constants.ENSRegistrarRopsten
        case .rinkeby: return Constants.ENSRegistrarRinkeby
        case .xDai: return Constants.ENSRegistrarXDAI
        default: return Constants.ENSRegistrarAddress
        }
    }

    var networkRequestsQueuePriority: Operation.QueuePriority {
        switch self {
        case .main, .xDai:
            return .normal
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .custom:
            return .low
        }
    }

    var blockChainName: String {
        switch self {
        case .xDai:
            return R.string.localizable.blockchainXDAI()
        case .main, .rinkeby, .ropsten, .custom, .callisto, .classic, .kovan, .sokol, .poa, .goerli:
            return R.string.localizable.blockchainEthereum()
        }
    }

    var blockChainNameColor: UIColor {
        switch self {
        case .main: return .init(red: 41, green: 134, blue: 175)
        case .classic: return .init(red: 55, green: 137, blue: 55)
        case .callisto: return .init(red: 88, green: 56, blue: 163)
        case .kovan: return .init(red: 112, green: 87, blue: 141)
        case .ropsten, .custom: return .init(red: 255, green: 74, blue: 141)
        case .rinkeby: return .init(red: 246, green: 195, blue: 67)
        case .poa: return .init(red: 88, green: 56, blue: 163)
        case .sokol: return .init(red: 107, green: 53, blue: 162)
        case .goerli: return .init(red: 187, green: 174, blue: 154)
        case .xDai: return .init(red: 253, green: 176, blue: 61)
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
            case RPCServer.goerli.name: return .goerli
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
            case RPCServer.goerli.chainID: return .goerli
            default: return .main
            }
        }()
    }

    init?(withMagicLinkHost magicLinkHost: String) {
        var server: RPCServer? = {
            switch magicLinkHost {
            case RPCServer.main.magicLinkHost: return .main
            case RPCServer.classic.magicLinkHost: return .classic
            case RPCServer.callisto.magicLinkHost: return .callisto
            case RPCServer.kovan.magicLinkHost: return .kovan
            case RPCServer.ropsten.magicLinkHost: return .ropsten
            case RPCServer.rinkeby.magicLinkHost: return .rinkeby
            case RPCServer.poa.magicLinkHost: return .poa
            case RPCServer.sokol.magicLinkHost: return .sokol
            case RPCServer.xDai.magicLinkHost: return .xDai
            case RPCServer.goerli.magicLinkHost: return .goerli
            default: return nil
            }
        }()
        //Special case to support legacy host name
        if magicLinkHost == Constants.legacyMagicLinkHost {
            server = .main
        }
        guard let createdServer = server else { return nil }
        self = createdServer
    }

    init?(withMagicLink url: URL) {
        guard let host = url.host, let server = RPCServer(withMagicLinkHost: host) else { return nil }
        self = server
    }

    //We'll have to manually new cases here
    static var allCases: [RPCServer] {
        return [
            .main,
            .kovan,
            .ropsten,
            .rinkeby,
            .poa,
            .sokol,
            .classic,
            .xDai,
            .goerli
        ]
    }
}
