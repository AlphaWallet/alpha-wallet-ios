// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import web3swift
import BigInt

extension RPCServer {
    public static func custom(chainId: Int) -> RPCServer {
        return .custom(.custom(chainId: chainId))
    }
}

// swiftlint:disable type_body_length
public enum RPCServer: Hashable, CaseIterable {
    enum RpcNodeBatchSupport {
        case noBatching
        case batch(Int)
    }

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
    public private(set) static var customServers: [Self] = customRpcs.map { RPCServer.custom($0) }

    case main
    case kovan
    case ropsten
    case rinkeby
    case poa
    case sokol
    case classic
    //As of 20210601, `.callisto` doesn't eth_blockNumber because their endpoint requires including `"params": []` in the payload even if it's empty and we don't.
    //As of 20210601, `.callisto` doesn't support eth_call according to https://testnet-explorer.callisto.network/eth-rpc-api-docs
    case callisto
    case xDai
    case phi
    case goerli
    case artis_sigma1
    case artis_tau1
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
    case optimisticKovan
    case cronosTestnet
    case custom(CustomRPC)
    case arbitrum
    case arbitrumRinkeby
    case palm
    case palmTestnet
    case klaytnCypress
    case klaytnBaobabTestnet
    case ioTeX
    case ioTeXTestnet
    case candle

    public enum EtherscanCompatibleType: String, Codable {
        case etherscan
        case blockscout
        case unknown
    }

    //Using this property avoids direct reference to `.main`, which could be a sign of a possible crash — i.e. using `.main` when it is disabled by the user
    public static var forResolvingEns: RPCServer {
        .main
    }

    public var chainID: Int {
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
        case .phi: return 4181
        case .goerli: return 5
        case .artis_sigma1: return 246529
        case .artis_tau1: return 246785
        case .binance_smart_chain: return 56
        case .binance_smart_chain_testnet: return 97
        case .heco: return 128
        case .heco_testnet: return 256
        case .custom(let custom):
            return custom.chainID
        case .fantom: return 250
        case .fantom_testnet: return 0xfa2
        case .avalanche: return 0xa86a
        case .avalanche_testnet: return 0xa869
        case .polygon: return 137
        case .mumbai_testnet: return 80001
        case .optimistic: return 10
        case .optimisticKovan: return 69
        case .cronosTestnet: return 338
        case .arbitrum: return 42161
        case .arbitrumRinkeby: return 421611
        case .palm: return 11297108109
        case .palmTestnet: return 11297108099
        case .klaytnCypress: return 8217
        case .klaytnBaobabTestnet: return 1001
        case .ioTeX: return 4689
        case .ioTeXTestnet: return 4690
        case .candle: return 534
        }
    }

    public var name: String {
        switch self {
        case .main: return "Ethereum"
        case .kovan: return "Kovan"
        case .ropsten: return "Ropsten"
        case .rinkeby: return "Rinkeby"
        case .poa: return "POA Network"
        case .sokol: return "Sokol"
        case .classic: return "Ethereum Classic"
        case .callisto: return "Callisto"
        case .xDai: return "Gnosis"
        case .phi: return "PHI"
        case .goerli: return "Goerli"
        case .artis_sigma1: return "ARTIS sigma1"
        case .artis_tau1: return "ARTIS tau1"
        case .binance_smart_chain: return "Binance (BSC)"
        case .binance_smart_chain_testnet: return "Binance (BSC) Testnet"
        case .heco: return "Heco"
        case .heco_testnet: return "Heco Testnet"
        case .custom(let custom): return custom.chainName
        case .fantom: return "Fantom Opera"
        case .fantom_testnet: return "Fantom Testnet"
        case .avalanche: return "Avalanche Mainnet C-Chain"
        case .avalanche_testnet: return "Avalanche FUJI C-Chain"
        case .polygon: return "Polygon Mainnet"
        case .mumbai_testnet: return "Mumbai Testnet"
        case .optimistic: return "Optimistic Ethereum"
        case .optimisticKovan: return "Optimistic Kovan"
        case .cronosTestnet: return "Cronos Testnet"
        case .arbitrum: return "Arbitrum One"
        case .arbitrumRinkeby: return "Arbitrum Rinkeby"
        case .palm: return "Palm"
        case .palmTestnet: return "Palm (Testnet)"
        case .klaytnCypress: return "Klaytn Cypress"
        case .klaytnBaobabTestnet: return "Klaytn Baobab"
        case .ioTeX: return "IoTeX Mainnet"
        case .ioTeXTestnet: return "IoTeX Testnet"
        case .candle: return "Candle"
        }
    }

    public var isTestnet: Bool {
        switch self {
        case .xDai, .phi, .classic, .main, .poa, .callisto, .binance_smart_chain, .artis_sigma1, .heco, .fantom, .avalanche, .candle, .polygon, .optimistic, .arbitrum, .palm, .klaytnCypress, .ioTeX:
            return false
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .optimisticKovan, .cronosTestnet, .palmTestnet, .arbitrumRinkeby, .klaytnBaobabTestnet, .ioTeXTestnet:
            return true
        case .custom(let custom):
            return custom.isTestnet
        }
    }

    public var customRpc: CustomRPC? {
        switch self {
        case .xDai, .phi, .classic, .main, .poa, .callisto, .binance_smart_chain, .artis_sigma1, .heco, .fantom, .avalanche, .candle, .polygon, .optimistic, .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnBaobabTestnet, .klaytnCypress, .ioTeX, .ioTeXTestnet:
            return nil
        case .custom(let custom):
            return custom
        }
    }

    public var isCustom: Bool {
        customRpc != nil
    }

    public var etherscanURLForGeneralTransactionHistory: URL? {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .poa, .classic, .goerli, .xDai, .artis_sigma1, .artis_tau1, .candle, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .sokol, .callisto, .optimistic, .optimisticKovan, .cronosTestnet, .custom, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return etherscanApiRoot?.appendingQueryString("module=account&action=txlist")
        case .heco: return nil
        case .heco_testnet: return nil
        case .fantom: return nil
        case .fantom_testnet: return nil
        case .avalanche: return nil
        case .avalanche_testnet: return nil
        case .mumbai_testnet: return nil
        case .klaytnCypress, .klaytnBaobabTestnet: return nil
        case .phi: return nil
        case .ioTeX, .ioTeXTestnet: return nil
        }
    }

    ///etherscan-compatible erc20 transaction event APIs
    ///The fetch ERC20 transactions endpoint from Etherscan returns only ERC20 token transactions but the Blockscout version also includes ERC721 transactions too (so it's likely other types that it can detect will be returned too); thus we should check the token type rather than assume that they are all ERC20
    public var etherscanURLForTokenTransactionHistory: URL? {
        switch etherscanCompatibleType {
        case .etherscan, .blockscout: return etherscanApiRoot?.appendingQueryString("module=account&action=tokentx")
        case .unknown: return nil
        }
    }

    public var etherscanWebpageRoot: URL? {
        let urlString: String? = {
            switch self {
            case .main: return "https://cn.etherscan.com"
            case .ropsten: return "https://ropsten.etherscan.io"
            case .rinkeby: return "https://rinkeby.etherscan.io"
            case .kovan: return "https://kovan.etherscan.io"
            case .goerli: return "https://goerli.etherscan.io"
            case .heco_testnet: return "https://testnet.hecoinfo.com"
            case .heco: return "https://hecoinfo.com"
            case .fantom: return "https://ftmscan.com"
            case .xDai: return "https://blockscout.com/poa/dai"
            case .phi: return "https://explorer.phi.network"
            case .poa: return "https://blockscout.com/poa/core"
            case .sokol: return "https://blockscout.com/poa/sokol"
            case .classic: return "https://blockscout.com/etc/mainnet"
            case .callisto: return "https://explorer.callisto.network"
            case .artis_sigma1: return "https://explorer.sigma1.artis.network"
            case .artis_tau1: return "https://explorer.tau1.artis.network"
            case .binance_smart_chain: return "https://bscscan.com"
            case .binance_smart_chain_testnet: return "https://testnet.bscscan.com"
            case .polygon: return "https://polygonscan.com"
            case .mumbai_testnet: return "https://mumbai.polygonscan.com"
            case .optimistic: return "https://optimistic.etherscan.io"
            case .optimisticKovan: return "https://kovan-optimistic.etherscan.io"
            case .cronosTestnet: return "https://cronos-explorer.crypto.org"
            case .custom: return nil
            case .fantom_testnet, .avalanche, .avalanche_testnet: return nil
            case .arbitrum: return "https://arbiscan.io"
            case .arbitrumRinkeby: return "https://testnet.arbiscan.io"
            case .palm: return "https://explorer.palm.io"
            case .palmTestnet: return "https://explorer.palm-uat.xyz"
            case .klaytnCypress: return "https://scope.klaytn.com"
            case .klaytnBaobabTestnet: return "https://baobab.scope.klaytn.com"
            case .ioTeX: return "https://iotexscan.io"
            case .ioTeXTestnet: return "https://testnet.iotexscan.io"
            case .candle: return "https://candleexplorer.com"
            }
        }()
        return urlString.flatMap { URL(string: $0) }
    }

    public var etherscanApiRoot: URL? {
        let urlString: String? = {
            switch self {
            case .main: return "https://api-cn.etherscan.com/api"
            case .kovan: return "https://api-kovan.etherscan.io/api"
            case .ropsten: return "https://api-ropsten.etherscan.io/api"
            case .rinkeby: return "https://api-rinkeby.etherscan.io/api"
            case .goerli: return "https://api-goerli.etherscan.io/api"
            case .classic: return "https://blockscout.com/etc/mainnet/api"
            case .callisto: return "https://explorer.callisto.network/api"
            case .poa: return "https://blockscout.com/poa/core/api"
            case .xDai: return "https://blockscout.com/poa/xdai/api"
            case .sokol: return "https://blockscout.com/poa/sokol/api"
            case .artis_sigma1: return "https://explorer.sigma1.artis.network/api"
            case .artis_tau1: return "https://explorer.tau1.artis.network/api"
            case .binance_smart_chain: return "https://api.bscscan.com/api"
            case .binance_smart_chain_testnet: return "https://api-testnet.bscscan.com/api"
            case .heco_testnet: return "https://api-testnet.hecoinfo.com/api"
            case .heco: return "https://api.hecoinfo.com/api"
            case .custom(let custom):
                return custom.explorerEndpoint
                        .flatMap { URL(string: $0) }
                        .flatMap { $0.appendingPathComponent("api").absoluteString }
            case .fantom: return "https://api.ftmscan.com/api"
            //TODO fix etherscan-compatible API endpoint
            case .fantom_testnet: return "https://explorer.testnet.fantom.network/tx/api"
            //TODO fix etherscan-compatible API endpoint
            case .avalanche: return "https://cchain.explorer.avax.network/tx/api"
            //TODO fix etherscan-compatible API endpoint
            case .avalanche_testnet: return "https://cchain.explorer.avax-test.network/tx/api"
            case .polygon: return "https://api.polygonscan.com/api"
            case .mumbai_testnet: return "https://api-testnet.polygonscan.com/api"
            case .optimistic: return "https://api-optimistic.etherscan.io/api"
            case .optimisticKovan: return "https://api-kovan-optimistic.etherscan.io/api"
            case .cronosTestnet: return "https://cronos-explorer.crypto.org/api"
            case .arbitrum: return "https://api.arbiscan.io/api"
            case .arbitrumRinkeby: return "https://testnet.arbiscan.io/api"
            case .palm: return "https://explorer.palm.io/api"
            case .palmTestnet: return "https://explorer.palm-uat.xyz/api"
            case .klaytnCypress: return nil
            case .klaytnBaobabTestnet: return nil
            case .phi: return nil
            case .ioTeX: return nil
            case .ioTeXTestnet: return nil
            case .candle: return "https://candleexplorer.com/api"
            }
        }()
        return urlString.flatMap { URL(string: $0) }
    }

    //If Etherscan, action=tokentx for ERC20 and action=tokennfttx for ERC721. If Blockscout-compatible, action=tokentx includes both ERC20 and ERC721. tokennfttx is not supported.
    public var etherscanURLForERC721TransactionHistory: URL? {
        switch etherscanCompatibleType {
        case .etherscan: return etherscanApiRoot?.appendingQueryString("module=account&action=tokennfttx")
        case .blockscout: return etherscanApiRoot?.appendingQueryString("module=account&action=tokentx")
        case .unknown: return nil
        }
    }

    private var etherscanCompatibleType: EtherscanCompatibleType {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .goerli, .fantom, .heco, .heco_testnet, .optimistic, .optimisticKovan, .binance_smart_chain, .binance_smart_chain_testnet, .polygon, .arbitrum, .arbitrumRinkeby:
            return .etherscan
        case .poa, .sokol, .classic, .xDai, .phi, .artis_sigma1, .artis_tau1, .mumbai_testnet, .callisto, .cronosTestnet, .palm, .palmTestnet:
            return .blockscout
        case .fantom_testnet, .avalanche, .avalanche_testnet, .candle:
            return .unknown
        case .klaytnCypress, .klaytnBaobabTestnet: return .etherscan
        case .custom(let custom):
            return custom.etherscanCompatibleType
        case .ioTeX, .ioTeXTestnet: return .etherscan
        }
    }

    public var etherscanApiKey: String? {
        switch self {
        case .main, .kovan, .ropsten, .rinkeby, .goerli, .optimistic, .optimisticKovan, .arbitrum, .arbitrumRinkeby: return Constants.Credentials.etherscanKey
        case .binance_smart_chain: return Constants.Credentials.binanceSmartChainExplorerApiKey //Key not needed for testnet (empirically)
        case .polygon, .mumbai_testnet: return Constants.Credentials.polygonScanExplorerApiKey
        case .fantom, .heco, .heco_testnet, .binance_smart_chain_testnet: return nil
        case .klaytnCypress, .klaytnBaobabTestnet: return nil
        case .poa, .sokol, .classic, .xDai, .phi, .artis_sigma1, .artis_tau1, .callisto, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .cronosTestnet, .palm, .palmTestnet, .custom: return nil
        case .ioTeX, .ioTeXTestnet: return nil
        }
    }

    //Some chains like Optimistic have the native token share the same balance as a distinct ERC20 token. On such chains, we must not show both of them at the same time
    public var erc20AddressForNativeToken: AlphaWallet.Address? {
        switch self {
        case .optimistic, .optimisticKovan: return AlphaWallet.Address(string: "0x4200000000000000000000000000000000000006")!
        case .main, .ropsten, .rinkeby, .kovan, .goerli, .fantom, .heco, .heco_testnet, .binance_smart_chain, .binance_smart_chain_testnet, .polygon, .poa, .sokol, .classic, .xDai, .phi, .artis_sigma1, .artis_tau1, .mumbai_testnet, .callisto, .cronosTestnet, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .custom, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet: return nil
        case .klaytnCypress, .klaytnBaobabTestnet: return nil
        case .ioTeX, .ioTeXTestnet: return nil
        }
    }

    //Optimistic don't allow changing the gas price and limit
    public var canUserChangeGas: Bool {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .goerli, .fantom, .heco, .heco_testnet, .binance_smart_chain, .binance_smart_chain_testnet, .candle, .polygon, .poa, .sokol, .classic, .xDai, .phi, .artis_sigma1, .artis_tau1, .mumbai_testnet, .callisto, .cronosTestnet, .fantom_testnet, .avalanche, .avalanche_testnet, .custom, .arbitrum, .palm, .palmTestnet: return true
        case .optimistic, .optimisticKovan, .arbitrumRinkeby, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet: return false
        }
    }

    public var shouldAddBufferWhenEstimatingGasPrice: Bool {
        switch self {
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return true
        case .phi:
            //PHI chain has very low gas requirements (2000wei as of writing) so we must not add 1gwei to it
            return false
        }
    }

    public func getEtherscanURLForGeneralTransactionHistory(for address: AlphaWallet.Address, startBlock: Int?) -> URL? {
         etherscanURLForGeneralTransactionHistory.flatMap {
             let apiKeyParameter: String
             if let apiKey = etherscanApiKey {
                 apiKeyParameter = "&apikey=\(apiKey)"
             } else {
                 apiKeyParameter = ""
             }
             let url = $0.appendingQueryString("address=\(address.eip55String)\(apiKeyParameter)")
             if let startBlock = startBlock {
                 return url?.appendingQueryString("startblock=\(startBlock)")
             } else {
                 return url
             }
         }
    }

    public func getEtherscanURLForTokenTransactionHistory(for address: AlphaWallet.Address, startBlock: Int?) -> URL? {
        etherscanURLForTokenTransactionHistory.flatMap {
            let apiKeyParameter: String
            if let apiKey = etherscanApiKey {
                apiKeyParameter = "&apikey=\(apiKey)"
            } else {
                apiKeyParameter = ""
            }
            let url = $0.appendingQueryString("address=\(address.eip55String)\(apiKeyParameter)")
            if let startBlock = startBlock {
                return url?.appendingQueryString("startblock=\(startBlock)")
            } else {
                return url
            }
        }
    }

    public func getEtherscanURLForERC721TransactionHistory(for address: AlphaWallet.Address, startBlock: Int?) -> URL? {
        etherscanURLForERC721TransactionHistory.flatMap {
            let apiKeyParameter: String
            if let apiKey = etherscanApiKey {
                apiKeyParameter = "&apikey=\(apiKey)"
            } else {
                apiKeyParameter = ""
            }
            let url = $0.appendingQueryString("address=\(address.eip55String)\(apiKeyParameter)")
            if let startBlock = startBlock {
                return url?.appendingQueryString("startblock=\(startBlock)")
            } else {
                return url
            }
        }
    }

    //Can't use https://blockscout.com/poa/dai/address/ even though it ultimately redirects there because blockscout (tested on 20190620), blockscout.com is only able to show that URL after the address has been searched (with the ?q= URL)
    public func etherscanContractDetailsWebPageURL(for address: AlphaWallet.Address) -> URL? {
        switch self {
        case .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return etherscanWebpageRoot?.appendingPathComponent("account").appendingPathComponent(address.eip55String)
        case .main, .ropsten, .rinkeby, .kovan, .xDai, .phi, .goerli, .poa, .sokol, .classic, .callisto, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            switch etherscanCompatibleType {
            case .etherscan:
                return etherscanWebpageRoot?.appendingPathComponent("address").appendingPathComponent(address.eip55String)
            case .blockscout:
                return etherscanWebpageRoot?.appendingPathComponent("search").appendingQueryString("q=\(address.eip55String)")
            case .unknown:
                return nil
            }
        }
    }

    //We assume that only Etherscan supports this and only for Ethereum mainnet: The token page instead of contract page
    //TODO check if other Etherscan networks can support this
    //TODO check if Blockscout can support this
    public func etherscanTokenDetailsWebPageURL(for address: AlphaWallet.Address) -> URL? {
        switch self {
        case .main, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return etherscanWebpageRoot?.appendingPathComponent("token").appendingPathComponent(address.eip55String)
        case .ropsten, .rinkeby, .kovan, .xDai, .phi, .goerli, .poa, .sokol, .classic, .callisto, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return etherscanContractDetailsWebPageURL(for: address)
        }
    }

    public var priceID: AlphaWallet.Address {
        switch self {
        case .main, .ropsten, .rinkeby, .kovan, .sokol, .custom, .xDai, .phi, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return AlphaWallet.Address(string: "0x000000000000000000000000000000000000003c")!
        case .poa: return AlphaWallet.Address(string: "0x00000000000000000000000000000000000000AC")!
        case .classic: return AlphaWallet.Address(string: "0x000000000000000000000000000000000000003D")!
        case .callisto: return AlphaWallet.Address(string: "0x0000000000000000000000000000000000000334")!
        }
    }

    public var symbol: String {
        switch self {
        case .main: return "ETH"
        case .classic: return "ETC"
        case .callisto: return "CLO"
        case .kovan, .ropsten, .rinkeby: return "ETH"
        case .poa, .sokol: return "POA"
        case .xDai: return "xDai"
        case .phi: return "PHI"
        case .goerli: return "ETH"
        case .artis_sigma1, .artis_tau1: return "ATS"
        case .binance_smart_chain, .binance_smart_chain_testnet: return "BNB"
        case .heco, .heco_testnet: return "HT"
        case .custom(let custom): return custom.symbol ?? "ETH"
        case .fantom, .fantom_testnet: return "FTM"
        case .avalanche, .avalanche_testnet: return "AVAX"
        case .polygon, .mumbai_testnet: return "MATIC"
        case .optimistic: return "ETH"
        case .optimisticKovan: return "ETH"
        case .cronosTestnet: return "tCRO"
        case .arbitrum: return "AETH"
        case .arbitrumRinkeby: return "ARETH"
        case .palm: return "PALM"
        case .palmTestnet: return "PALM"
        case .klaytnCypress, .klaytnBaobabTestnet: return "KLAY"
        case .ioTeX, .ioTeXTestnet: return "ioTeX"
        case .candle: return "CNDL"
        }
    }

    public var cryptoCurrencyName: String {
        switch self {
        case .main, .classic, .callisto, .kovan, .ropsten, .rinkeby, .poa, .sokol, .goerli, .optimistic, .optimisticKovan: return "Ether"
        case .xDai: return "xDai"
        case .phi: return "PHI"
        case .binance_smart_chain, .binance_smart_chain_testnet: return "BNB"
        case .artis_sigma1, .artis_tau1: return "ATS"
        case .heco, .heco_testnet: return "HT"
        case .fantom, .fantom_testnet: return "FTM"
        case .avalanche, .avalanche_testnet: return "AVAX"
        case .polygon, .mumbai_testnet: return "MATIC"
        case .cronosTestnet: return "tCRO"
        case .custom(let custom): return custom.nativeCryptoTokenName ?? "Ether"
        case .arbitrum: return "AETH"
        case .arbitrumRinkeby: return "ARETH"
        case .palm: return "PALM"
        case .palmTestnet: return "PALM"
        case .klaytnCypress, .klaytnBaobabTestnet: return "KLAY"
        case .ioTeX, .ioTeXTestnet: return "ioTeX"
        case .candle: return "CNDL"
        }
    }

    public var decimals: Int {
        return 18
    }

    public var web3Network: Networks {
        switch self {
        case .main: return .Mainnet
        case .kovan: return .Kovan
        case .ropsten: return .Ropsten
        case .rinkeby: return .Rinkeby
        case .poa, .sokol, .classic, .callisto, .xDai, .phi, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .custom, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return .Custom(networkID: BigUInt(chainID))
        }
    }

    public var magicLinkPrefix: URL {
        let urlString = "https://\(magicLinkHost)/"
        return URL(string: urlString)!
    }

    public var magicLinkHost: String {
        switch self {
        case .main: return Constants.mainnetMagicLinkHost
        case .kovan: return Constants.kovanMagicLinkHost
        case .ropsten: return Constants.ropstenMagicLinkHost
        case .rinkeby: return Constants.rinkebyMagicLinkHost
        case .poa: return Constants.poaMagicLinkHost
        case .sokol: return Constants.sokolMagicLinkHost
        case .classic: return Constants.classicMagicLinkHost
        case .callisto: return Constants.callistoMagicLinkHost
        case .goerli: return Constants.goerliMagicLinkHost
        case .xDai: return Constants.xDaiMagicLinkHost
        case .phi: return Constants.phiMagicLinkHost
        case .artis_sigma1: return Constants.artisSigma1MagicLinkHost
        case .artis_tau1: return Constants.artisTau1MagicLinkHost
        case .binance_smart_chain: return Constants.binanceMagicLinkHost
        case .binance_smart_chain_testnet: return Constants.binanceTestMagicLinkHost
        case .custom: return Constants.customMagicLinkHost
        case .heco: return Constants.hecoMagicLinkHost
        case .heco_testnet: return Constants.hecoTestMagicLinkHost
        case .fantom: return Constants.fantomMagicLinkHost
        case .fantom_testnet: return Constants.fantomTestMagicLinkHost
        case .avalanche: return Constants.avalancheMagicLinkHost
        case .avalanche_testnet: return Constants.avalancheTestMagicLinkHost
        case .polygon: return Constants.maticMagicLinkHost
        case .mumbai_testnet: return Constants.mumbaiTestMagicLinkHost
        case .optimistic: return Constants.optimisticMagicLinkHost
        case .optimisticKovan: return Constants.optimisticTestMagicLinkHost
        case .cronosTestnet: return Constants.cronosTestMagicLinkHost
        case .arbitrum: return Constants.arbitrumMagicLinkHost
        case .arbitrumRinkeby: return Constants.arbitrumRinkebyMagicLinkHost
        case .palm: return Constants.palmMagicLinkHost
        case .palmTestnet: return Constants.palmTestnetMagicLinkHost
        case .klaytnCypress: return Constants.klaytnCypressMagicLinkHost
        case .klaytnBaobabTestnet: return Constants.klaytnBaobabTestnetMagicLinkHost
        case .ioTeX: return Constants.ioTeXMagicLinkHost
        case .ioTeXTestnet: return Constants.ioTeXTestnetMagicLinkHost
        case .candle: return Constants.candleMagicLinkHost
        }
    }

    public var rpcURL: URL {
        let urlString: String = {
            switch self {
            case .main: return "https://mainnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .classic: return "https://www.ethercluster.com/etc"
            case .callisto: return "https://explorer.callisto.network/api/eth-rpc"
            case .kovan: return "https://kovan.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .ropsten: return "https://ropsten.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .rinkeby: return "https://rinkeby.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .poa: return "https://core.poa.network"
            case .sokol: return "https://sokol.poa.network"
            case .goerli: return "https://goerli.infura.io/v3/\(Constants.Credentials.infuraKey)"
            //https://rpc.ankr.com/gnosis handles batching and errors differently from other RPC nodes
            // if there's an error, the `id` field is null (unlike others)
            // if it's a batched request of N requests and there's an error, 1 error is returned instead of N array and the `id` field in the error is null (unlike others)
            case .xDai: return "https://rpc.ankr.com/gnosis"
            case .phi: return "https://rpc1.phi.network"
            case .artis_sigma1: return "https://rpc.sigma1.artis.network"
            case .artis_tau1: return "https://rpc.tau1.artis.network"
            case .binance_smart_chain: return "https://bsc-dataseed.binance.org"
            case .binance_smart_chain_testnet: return "https://data-seed-prebsc-1-s1.binance.org:8545"
            case .heco: return "https://http-mainnet.hecochain.com"
            case .heco_testnet: return "https://http-testnet.hecochain.com"
            case .custom(let custom): return custom.rpcEndpoint
            case .fantom: return "https://rpc.ftm.tools"
            case .fantom_testnet: return "https://rpc.testnet.fantom.network/"
            case .avalanche: return "https://api.avax.network/ext/bc/C/rpc"
            case .avalanche_testnet: return "https://api.avax-test.network/ext/bc/C/rpc"
            case .polygon: return "https://polygon-mainnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .mumbai_testnet: return "https://polygon-mumbai.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .optimistic: return "https://mainnet.optimism.io"
            case .optimisticKovan: return "https://kovan.optimism.io"
            case .cronosTestnet: return "https://cronos-testnet.crypto.org:8545"
            case .arbitrum: return "https://arbitrum-mainnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .arbitrumRinkeby: return "https://arbitrum-rinkeby.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .palm: return "https://palm-mainnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .palmTestnet: return "https://palm-testnet.infura.io/v3/\(Constants.Credentials.infuraKey)"
            case .klaytnCypress:
                let basicAuth = Constants.Credentials.klaytnRpcNodeKeyBasicAuth
                if basicAuth.isEmpty {
                    return "https://public-node-api.klaytnapi.com/v1/cypress"
                } else {
                    return "https://node-api.klaytnapi.com/v1/klaytn"
                }
            case .klaytnBaobabTestnet:
                let basicAuth = Constants.Credentials.klaytnRpcNodeKeyBasicAuth
                if basicAuth.isEmpty {
                    return "https://api.baobab.klaytn.net:8651"
                } else {
                    return "https://node-api.klaytnapi.com/v1/klaytn"
                }
            case .ioTeX: return "https://babel-api.mainnet.iotex.io"
            case .ioTeXTestnet: return "https://babel-api.testnet.iotex.io"
            case .candle: return "https://rpc.cndlchain.com"
            }
        }()
        return URL(string: urlString)!
    }

    public var rpcHeaders: RPCNodeHTTPHeaders {
        switch self {
        case .klaytnCypress, .klaytnBaobabTestnet:
            let basicAuth = Constants.Credentials.klaytnRpcNodeKeyBasicAuth
            if basicAuth.isEmpty {
                return .init()
            } else {
                return [
                    "Authorization": "Basic \(basicAuth)",
                    "x-chain-id": "\(chainID)",
                ]
            }
        case .main, .classic, .callisto, .kovan, .ropsten, .rinkeby, .poa, .sokol, .goerli, .xDai, .phi, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet:
            return .init()
        }
    }

    public var transactionInfoEndpoints: URL? {
        switch self {
        case .main, .kovan, .ropsten, .rinkeby, .phi, .goerli, .classic, .poa, .xDai, .sokol, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .fantom, .candle, .polygon, .mumbai_testnet, .heco, .heco_testnet, .callisto, .optimistic, .optimisticKovan, .cronosTestnet, .custom, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            return etherscanApiRoot
        case .fantom_testnet: return URL(string: "https://explorer.testnet.fantom.network/tx/")
        case .avalanche: return URL(string: "https://cchain.explorer.avax.network/tx/")
        case .avalanche_testnet: return URL(string: "https://cchain.explorer.avax-test.network/tx/")
        }
    }

    public var networkRequestsQueuePriority: Operation.QueuePriority {
        switch self {
        case .main, .polygon, .klaytnCypress, .klaytnBaobabTestnet: return .normal
        case .xDai, .kovan, .ropsten, .rinkeby, .poa, .phi, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet: return .low
        }
    }

    public var transactionProviderType: SingleChainTransactionProvider.Type {
        switch self {
        case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .phi, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return EtherscanSingleChainTransactionProvider.self
        case .klaytnCypress, .klaytnBaobabTestnet:
            return CovalentSingleChainTransactionProvider.self
        case .ioTeX, .ioTeXTestnet:
            return CovalentSingleChainTransactionProvider.self
        }
    }

    public init(name: String) {
        //TODO defaulting to .main is bad
        self = Self.availableServers.first { $0.name == name } ?? .main
    }

    public init(chainID: Int) {
        //TODO defaulting to .main is bad
        self = Self.availableServers.first { $0.chainID == chainID } ?? .main
    }

    public init?(chainIdOptional chainID: Int) {
        guard let server = Self.availableServers.first(where: { $0.chainID == chainID }) else {
            return nil
        }
        self = server
    }

    public init?(withMagicLinkHost magicLinkHost: String) {
        var server: RPCServer?
        //Special case to support legacy host name
        if magicLinkHost == Constants.legacyMagicLinkHost {
            server = .main
        } else {
            server = Self.availableServers.first { $0.magicLinkHost == magicLinkHost }
        }
        guard let createdServer = server else { return nil }
        self = createdServer
    }

    public init?(withMagicLink url: URL) {
        guard let host = url.host, let server = RPCServer(withMagicLinkHost: host) else { return nil }
        self = server
    }

    //We'll have to manually new cases here
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static public var allCases: [RPCServer] {
        let all: [RPCServer] = [
            .main,
            .kovan,
            .ropsten,
            .rinkeby,
            .poa,
            .sokol,
            .classic,
            .xDai,
            .phi,
            .goerli,
            .artis_sigma1,
            .artis_tau1,
            .binance_smart_chain_testnet,
            .binance_smart_chain,
            .heco,
            .heco_testnet,
            .fantom,
            .fantom_testnet,
            .avalanche,
            .avalanche_testnet,
            .polygon,
            .callisto,
            .mumbai_testnet,
            .optimistic,
            .optimisticKovan,
            .cronosTestnet,
            .arbitrum,
            .arbitrumRinkeby,
            .klaytnCypress,
            .klaytnBaobabTestnet,
            .candle,
            //.ioTeX, //TODO: Disabled as non in Phase 1 anymore, need to take a look on transactions, native balances
            //.ioTeXTestnet
        ]
        if Features.default.isAvailable(.isPalmEnabled) {
            return all + [.palm, .palmTestnet]
        } else {
            return all
        }
    }

    public static var availableServers: [RPCServer] {
        allCases + RPCServer.customServers
    }

    private static func convertJsonToCustomRpcs(_ json: String?) -> [CustomRPC] {
        if let json = json {
            let data = json.data(using: .utf8)
            if let servers = try? JSONDecoder().decode([CustomRPC].self, from: data!) {
                return servers
            } else {
                return .init()
            }
        } else {
            return .init()
        }
    }

    public func makeMaximumToBlockForEvents(fromBlockNumber: UInt64) -> EventFilter.Block {
        switch self {
        case .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet:
            //These do not allow range more than 5000
            return .blockNumber(fromBlockNumber + 4990)
        case .optimistic:
            //These not allow range more than 10000
            return .blockNumber(fromBlockNumber + 9999)
        case .polygon:
            //These not allow range more than 3500
            return .blockNumber(fromBlockNumber + 3499)
        case .mumbai_testnet:
            //These not allow range more than 3500
            return .blockNumber(fromBlockNumber + 3499)
        case .cronosTestnet, .arbitrum, .arbitrumRinkeby:
            //These not allow range more than 100000
            return .blockNumber(fromBlockNumber + 99990)
        case .xDai:
            return .blockNumber(fromBlockNumber + 3000)
        case .main, .kovan, .ropsten, .rinkeby, .poa, .classic, .callisto, .phi, .goerli, .artis_sigma1, .artis_tau1, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .optimisticKovan, .sokol, .custom, .palm, .palmTestnet:
            return .latest
        case .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet:
            //These not allow range more than 10,000
            return .blockNumber(fromBlockNumber + 9999)
        case .candle:
            return .blockNumber(fromBlockNumber + 20000)
        }
    }

    public var displayOrderPriority: Int {
        switch self {
        case .main: return 1
        case .xDai: return 2
        case .classic: return 3
        case .poa: return 4
        case .ropsten: return 5
        case .kovan: return 6
        case .rinkeby: return 7
        case .sokol: return 8
        case .callisto: return 9
        case .goerli: return 10
        case .artis_sigma1: return 246529
        case .artis_tau1: return 246785
        case .binance_smart_chain: return 12
        case .binance_smart_chain_testnet: return 13
        case .custom(let custom): return 300000 + custom.chainID
        case .heco: return 14
        case .heco_testnet: return 15
        case .fantom: return 16
        case .fantom_testnet: return 17
        case .avalanche: return 18
        case .avalanche_testnet: return 19
        case .polygon: return 20
        case .mumbai_testnet: return 21
        case .optimistic: return 22
        case .optimisticKovan: return 23
        case .cronosTestnet: return 24
        case .arbitrum: return 25
        case .arbitrumRinkeby: return 26
        case .palm: return 27
        case .palmTestnet: return 28
        case .klaytnCypress: return 29
        case .klaytnBaobabTestnet: return 30
        case .phi: return 31
        case .ioTeX: return 32
        case .ioTeXTestnet: return 33
        case .candle: return 34
        }
    }

    public var explorerName: String {
        switch self {
        case .main, .kovan, .ropsten, .rinkeby, .goerli:
            return "Etherscan"
        case .classic, .poa, .custom, .callisto, .sokol, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return "\(name) Explorer"
        case .xDai:
            return "Blockscout"
        case .artis_sigma1, .artis_tau1:
            return "ARTIS"
        }
    }

    public var coinGeckoPlatform: String? {
        switch self {
        case .main: return "ethereum"
        case .classic: return "ethereum-classic"
        case .xDai: return "xdai"
        case .binance_smart_chain: return "binance-smart-chain"
        case .avalanche: return "avalanche"
        case .polygon: return "polygon-pos"
        case .fantom: return "fantom"
        case .arbitrum: return "arbitrum-one"
        case .klaytnCypress, .klaytnBaobabTestnet: return "klay-token"
        case .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom_testnet, .avalanche_testnet, .candle, .mumbai_testnet, .custom, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby, .phi, .ioTeX, .ioTeXTestnet:
            return nil
        }
    }

    public var coinBasePlatform: String? {
        switch self {
        case .main: return "ethereum"
        case .avalanche, .xDai, .classic, .fantom, .arbitrum, .candle, .polygon, .binance_smart_chain, .klaytnCypress, .klaytnBaobabTestnet, .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .custom, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby, .phi, .ioTeX, .ioTeXTestnet:
            return nil
        }
    }

    var shouldExcludeZeroGasPrice: Bool {
        switch self {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return true
        case .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .optimistic, .polygon, .mumbai_testnet, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .main, .kovan, .ropsten, .rinkeby, .poa, .classic, .callisto, .phi, .goerli, .artis_sigma1, .artis_tau1, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .optimisticKovan, .sokol, .custom, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet, .xDai, .candle:
            return false
        }
    }

    private var rpcNodeBatchSupport: RpcNodeBatchSupport {
        switch self {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return .noBatching
        case .xDai:
            return .batch(6)
        case .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .optimistic, .candle, .polygon, .mumbai_testnet, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .main, .kovan, .ropsten, .rinkeby, .poa, .classic, .callisto, .phi, .goerli, .artis_sigma1, .artis_tau1, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .optimisticKovan, .sokol, .custom, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet:
            return .batch(32)
        }
    }
}
// swiftlint:enable type_body_length

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

extension URL {
    //Much better to use URLComponents, but this is much simpler for our use. This probably doesn't percent-escape probably, but we shouldn't need it for the URLs we access here
	func appendingQueryString(_ queryString: String) -> URL? {
        let urlString = absoluteString
        if urlString.contains("?") {
            return URL(string: "\(urlString)&\(queryString)")
        } else {
            return URL(string: "\(urlString)?\(queryString)")
        }
	}
}

extension RPCServer {
    var conflictedServer: RPCServer? {
        for each in RPCServer.availableServers {
            if let index = RPCServer.allCases.index(where: { each == $0 }), each.isCustom {
                return RPCServer.allCases[index]
            } else {
                continue
            }
        }

        return nil
    }
}

extension RPCServer {
    var web3SwiftRpcNodeBatchSupportPolicy: JSONRPCrequestDispatcher.DispatchPolicy {
        switch rpcNodeBatchSupport {
        case .noBatching:
            return .NoBatching
        case .batch(let size):
            return .Batch(size)
        }
    }
}
