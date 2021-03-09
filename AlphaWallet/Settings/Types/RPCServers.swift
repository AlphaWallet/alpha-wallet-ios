// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import web3swift
import BigInt

// swiftlint:disable type_body_length
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
    case artis_sigma1
    case artis_tau1
    case binance_smart_chain
    case binance_smart_chain_testnet
    case heco
    case heco_testnet
    case custom(CustomRPC)
    case taiChi

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
        case .artis_sigma1: return 246529
        case .artis_tau1: return 246785
        case .binance_smart_chain: return 56
        case .binance_smart_chain_testnet: return 97
        case .heco: return 128
        case .heco_testnet: return 256
        case .custom(let custom): return custom.chainID
        case .taiChi: return 777777777
        }
    }

    //NOTE: non safe chain ID, use only for signing transactions, sending as param for URL Requests.
    var nonUniqueChainID: Int {
        switch self {
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .xDai:
            return chainID
        case .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom:
            return chainID
        case .taiChi:
            return 1
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
        case .artis_sigma1: return "ARTIS sigma1"
        case .artis_tau1: return "ARTIS tau1"
        case .binance_smart_chain: return "Binance"
        case .binance_smart_chain_testnet: return "Binance Testnet"
        case .heco: return "Heco"
        case .heco_testnet: return "Heco Testnet"
        case .custom(let custom):
            return custom.name
        case .taiChi: return "TaiChi"
        }
    }

    var isTestnet: Bool {
        switch self {
        case .xDai, .classic, .main, .poa, .callisto, .binance_smart_chain, .heco, .taiChi:
            return false
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .custom, .heco_testnet:
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
        case .classic: return Constants.classicEtherscanAPI
        case .callisto: return nil
        case .goerli: return Constants.goerliEtherscanAPI
        case .xDai: return Constants.xDaiAPI
        case .artis_sigma1: return nil
        case .artis_tau1: return nil
        case .binance_smart_chain: return nil
        case .binance_smart_chain_testnet: return nil
        case .heco: return nil
        case .heco_testnet: return nil
        case .custom: return nil
        case .taiChi: return nil
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
        case .classic: return Constants.classicAPIErc20Events
        case .callisto: return nil
        case .goerli: return Constants.goerliEtherscanAPIErc20Events
        case .xDai: return Constants.xDaiAPIErc20Events
        case .artis_sigma1: return nil
        case .artis_tau1: return nil
        case .binance_smart_chain: return nil
        case .binance_smart_chain_testnet: return nil
        case .heco: return nil
        case .heco_testnet: return nil
        case .custom: return nil
        case .taiChi: return nil
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
        case .artis_sigma1: return Constants.artisSigma1ContractPage
        case .artis_tau1: return Constants.artisTau1ContractPage
        case .binance_smart_chain: return Constants.binanceContractPage
        case .binance_smart_chain_testnet: return Constants.binanceTestnetContractPage
        case .custom: return Constants.mainnetEtherscanContractDetailsWebPageURL
        case .heco_testnet: return Constants.hecoTestnetContractPage
        case .heco: return Constants.hecoContractPage
        case .taiChi: return Constants.mainnetEtherscanContractDetailsWebPageURL
        }
    }

    //We assume that only Etherscan supports this and only for Ethereum mainnet: The token page instead of contract page
    var etherscanTokenDetailsWebPageURL: String {
        switch self {
        case .main:
            return Constants.mainnetEtherscanTokenDetailsWebPageURL
        case .ropsten, .rinkeby, .kovan, .xDai, .goerli, .poa, .sokol, .classic, .callisto, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet:
            return etherscanContractDetailsWebPageURL
        case .taiChi:
            return etherscanContractDetailsWebPageURL
        }
    }

    func etherscanAPIURLForTransactionList(for address: AlphaWallet.Address, startBlock: Int?) -> URL? {
         getEtherscanURL.flatMap {
             var url = "\($0)\(address.eip55String)&apikey=\(Constants.Credentials.etherscanKey)"
             if let startBlock = startBlock {
                 url = "\(url)&startBlock=\(startBlock)"
             }
             return URL(string: url)
         }
    }

    func etherscanAPIURLForERC20TxList(for address: AlphaWallet.Address, startBlock: Int?) -> URL? {
        getEtherscanURLERC20Events.flatMap {
            var url = "\($0)\(address.eip55String)&apikey=\(Constants.Credentials.etherscanKey)"
            if let startBlock = startBlock {
                url = "\(url)&startBlock=\(startBlock)"
            }
            return URL(string: url)
        }
    }

    func etherscanContractDetailsWebPageURL(for address: AlphaWallet.Address) -> URL {
        return URL(string: etherscanContractDetailsWebPageURL + address.eip55String)!
    }

    func etherscanTokenDetailsWebPageURL(for address: AlphaWallet.Address) -> URL {
        return URL(string: etherscanTokenDetailsWebPageURL + address.eip55String)!
    }

    var priceID: AlphaWallet.Address {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .sokol, .custom, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .taiChi:
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
        case .main, .poa, .classic, .callisto, .custom, .xDai, .artis_sigma1, .binance_smart_chain, .heco, .taiChi: return false
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .heco_testnet: return true
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
        case .artis_sigma1, .artis_tau1: return "ATS"
        case .binance_smart_chain, .binance_smart_chain_testnet: return "BNB"
        case .heco, .heco_testnet: return "HT"
        case .custom(let custom): return custom.symbol
        case .taiChi: return "ETH"
        }
    }

    var cryptoCurrencyName: String {
        switch self {
        case .main, .classic, .callisto, .kovan, .ropsten, .rinkeby, .poa, .sokol, .goerli, .custom:
            return "Ether"
        case .xDai:
            return "xDai"
        case .binance_smart_chain, .binance_smart_chain_testnet:
            return "BNB"
        case .artis_sigma1, .artis_tau1:
            return "ATS"
        case .heco, .heco_testnet:
            return "HT"
        case .taiChi:
            return "Ether"
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
        case .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .taiChi:
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
        case .artis_sigma1:
            return Constants.artisSigma1MagicLinkHost
        case .artis_tau1:
            return Constants.artisTau1MagicLinkHost
        case .binance_smart_chain:
            return Constants.binanceMagicLinkHost
        case .binance_smart_chain_testnet:
            return Constants.binanceTestMagicLinkHost
        case .custom:
            return Constants.customMagicLinkHost
        case .heco:
            return Constants.hecoMagicLinkHost
        case .heco_testnet:
            return Constants.hecoTestMagicLinkHost
        case .taiChi:
            return Constants.taiChiMagicLinkHost
        }
    }

    var rpcURL: URL {
        let urlString: String = {
            switch self {
            case .main: return "https://mainnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .classic: return "https://www.ethercluster.com/etc"
            case .callisto: return "https://callisto.network/" //TODO Add endpoint
            case .kovan: return "https://kovan.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .ropsten: return "https://ropsten.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .rinkeby: return "https://rinkeby.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .poa: return "https://core.poa.network"
            case .sokol: return "https://sokol.poa.network"
            case .goerli: return "https://goerli.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .xDai: return "https://dai.poa.network"
            case .artis_sigma1: return "https://rpc.sigma1.artis.network"
            case .artis_tau1: return "https://rpc.tau1.artis.network"
            case .binance_smart_chain: return "https://bsc-dataseed1.binance.org:443"
            case .binance_smart_chain_testnet: return "https://data-seed-prebsc-1-s1.binance.org:8545"
            case .heco: return "https://http-mainnet.hecochain.com"
            case .heco_testnet: return "https://http-testnet.hecochain.com"
            case .custom(let custom): return custom.endpoint
            case .taiChi: return "http://api.taichi.network:10000/rpc/\(Constants.Credentials.taiChiRPCKey)"
            }
        }()
        return URL(string: urlString)!
    }

    var transactionInfoEndpoints: URL {
        let urlString: String = {
            switch self {
            case .main: return "https://api-cn.etherscan.com"
            case .classic: return "https://blockscout.com/etc/mainnet/api"
            case .callisto: return "https://callisto.trustwalletapp.com"
            case .kovan: return "https://api-kovan.etherscan.io"
            case .ropsten: return "https://api-ropsten.etherscan.io"
            case .rinkeby: return "https://api-rinkeby.etherscan.io"
            case .poa: return "https://blockscout.com/poa/core/api"
            case .xDai: return "https://blockscout.com/poa/dai/api"
            case .sokol: return "https://blockscout.com/poa/sokol/api"
            case .goerli: return "https://api-goerli.etherscan.io"
            case .artis_sigma1: return "https://explorer.sigma1.artis.network/api"
            case .artis_tau1: return "https://explorer.tau1.artis.network/api"
            case .binance_smart_chain: return "https://bscscan.com/tx/"
            case .binance_smart_chain_testnet: return "https://testnet.bscscan.com/tx/"
            case .heco_testnet: return "https://scan-testnet.hecochain.com/tx/"
            case .heco: return "https://scan.hecochain.com/tx/"
            case .taiChi: return "https://api.taichi.network:10000/txscan/priTx?txHash=:txHash" //?? not sure what right url to use here
            case .custom: return "" // Enable? make optional
            //http://api.taichi.network:10000/rpc/48eb94c3c44d2de6ae495fdf6b293e60?txroute=private
            }
        }()
        return URL(string: urlString)!
    }

    var ensRegistrarContract: AlphaWallet.Address {
        switch self {
        case .main: return Constants.ENSRegistrarAddress
        case .ropsten: return Constants.ENSRegistrarRopsten
        case .rinkeby: return Constants.ENSRegistrarRinkeby
        case .goerli: return Constants.ENSRegistrarGoerli
        case .xDai, .kovan, .poa, .sokol, .classic, .callisto, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet:
            return Constants.ENSRegistrarAddress
        case .taiChi: return Constants.ENSRegistrarAddress
        }
    }

    var networkRequestsQueuePriority: Operation.QueuePriority {
        switch self {
        case .main, .xDai:
            return .normal
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .taiChi:
            return .low
        }
    }

    var blockChainName: String {
        switch self {
        case .xDai:
            return R.string.localizable.blockchainXDAI()
        case .artis_sigma1:
            return R.string.localizable.blockchainARTISSigma1()
        case .artis_tau1:
            return R.string.localizable.blockchainARTISTau1()
        case .binance_smart_chain:
            return R.string.localizable.blockchainBinance()
        case .binance_smart_chain_testnet:
            return R.string.localizable.blockchainBinanceTest()
        case .heco:
            return R.string.localizable.blockchainHeco()
        case .heco_testnet:
            return R.string.localizable.blockchainHecoTest()
        case .main, .rinkeby, .ropsten, .custom, .callisto, .classic, .kovan, .sokol, .poa, .goerli:
            return R.string.localizable.blockchainEthereum()
        case .taiChi:
            return R.string.localizable.blockchainTaichi()
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
        case .artis_sigma1: return .init(red: 83, green: 162, blue: 113)
        case .artis_tau1: return .init(red: 255, green: 117, blue: 153)
        case .binance_smart_chain, .binance_smart_chain_testnet: return .init(red: 255, green: 211, blue: 0)
        case .heco, .heco_testnet: return .init(hex: "1253FC")
        case .taiChi: return .red
        }
    }

    var transactionDataCoordinatorType: SingleChainTransactionDataCoordinator.Type {
        switch self {
        case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .heco, .heco_testnet, .taiChi:
            return SingleChainTransactionEtherscanDataCoordinator.self
        }
    }

    var iconImage: UIImage? {
        switch self {
        case .main:
            return R.image.eth()
        case .xDai:
            return R.image.xDai()
        case .poa:
            return R.image.tokenPoa()
        case  .classic:
            return R.image.tokenEtc()
        case .callisto:
            return R.image.tokenCallisto()
        case .artis_sigma1:
            return R.image.tokenArtis()
        case .binance_smart_chain:
            return R.image.tokenBnb()
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .custom:
            return nil
        case .heco:
            return R.image.hthecoMainnet()
        case .heco_testnet:
            return R.image.hthecoTestnet()
        case .taiChi:
            return nil
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
            case RPCServer.artis_sigma1.name: return .artis_sigma1
            case RPCServer.artis_tau1.name: return .artis_tau1
            case RPCServer.binance_smart_chain.name: return .binance_smart_chain
            case RPCServer.binance_smart_chain_testnet.name: return .binance_smart_chain_testnet
            case RPCServer.heco.name: return .heco
            case RPCServer.heco_testnet.name: return .heco_testnet
            case RPCServer.taiChi.name: return .taiChi
            default: return .main
            }
        }()
    }

    init(chainID: Int) {
        NSLog("xxx \(chainID)")
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
            case RPCServer.artis_sigma1.chainID: return .artis_sigma1
            case RPCServer.artis_tau1.chainID: return .artis_tau1
            case RPCServer.binance_smart_chain.chainID: return .binance_smart_chain
            case RPCServer.binance_smart_chain_testnet.chainID: return .binance_smart_chain_testnet
            case RPCServer.heco.chainID: return .heco
            case RPCServer.heco_testnet.chainID: return .heco_testnet
            case RPCServer.taiChi.chainID: return .taiChi
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
            case RPCServer.artis_sigma1.magicLinkHost: return .artis_sigma1
            case RPCServer.artis_tau1.magicLinkHost: return .artis_tau1
            case RPCServer.binance_smart_chain.magicLinkHost: return .binance_smart_chain
            case RPCServer.binance_smart_chain_testnet.magicLinkHost: return .binance_smart_chain_testnet
            case RPCServer.heco.magicLinkHost: return .heco
            case RPCServer.heco_testnet.magicLinkHost: return .heco_testnet
            case RPCServer.taiChi.magicLinkHost: return .taiChi
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
            .goerli,
            .artis_sigma1,
            .artis_tau1,
            .binance_smart_chain_testnet,
            .binance_smart_chain,
            .heco,
            .heco_testnet,
            .taiChi
        ]
    }
}
// swiftlint:enable type_body_length

extension RPCServer: Codable {
    private enum Keys: String, CodingKey {
        case chainId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let chainId = try container.decode(Int.self, forKey: .chainId)
        self = .init(chainID: chainId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(chainID, forKey: .chainId)
    }
}
