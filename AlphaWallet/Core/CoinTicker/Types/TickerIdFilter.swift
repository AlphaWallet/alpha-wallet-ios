//
//  TickerIdFilter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

struct TickerIdFilter {

    //https://polygonscan.com/address/0x0000000000000000000000000000000000001010
    static private let polygonMaticContract = AlphaWallet.Address(string: "0x0000000000000000000000000000000000001010")!

    func matches(token: TokenMappedToTicker, tickerId: TickerId) -> Bool {
        //We just filter out those that we don't think are supported by the API. One problem this helps to alleviate is in the API output, certain tickers have a non-empty platform yet the platform list might not be complete, eg. Ether on Ethereum mainnet:
        //{
        //   "symbol" : "eth",
        //   "id" : "ethereum",
        //   "name" : "Ethereum",
        //   "platforms" : {
        //      "huobi-token" : "0x64ff637fb478863b7468bc97d30a5bf3a428a1fd",
        //      "binance-smart-chain" : "0x2170ed0880ac9a755fd29b2688956bd959f933f8"
        //   }
        //},
        //This means we can only match solely by symbol, ignoring platform matches. But this means it's easy to match the wrong ticker (by symbol only). Hence, we at least remove those chains we don't think are supported
        //NOTE maybe its need to handle values like: `"0x270DE58F54649608D316fAa795a9941b355A2Bd0/token-transfers"`

        guard isServerSupported(token.server) else { return false }
        if let (_, maybeContractValue) = tickerId.platforms.first(where: { platformMatches($0.key, server: token.server) }) {
            func maybeAddressValue(from str: String) -> AlphaWallet.Address? {
                let rawValue = str.trimmed
                if rawValue.isEmpty {
                    //CoinGecko returns nullAddress as the value (contract) in `platforms` for tokens is sometimes an empty string: `"platforms" : { "ethereum" : "" }`, so we use the 0x0..0 address to represent them
                    return Constants.nullAddress
                } else if let value = AlphaWallet.Address(string: rawValue) {
                    //NOTE: trimmed to avoid values like `"0xFbdd194376de19a88118e84E279b977f165d01b8 "`
                    return value
                } else {
                    return nil
                }
            }
            guard let contract = maybeAddressValue(from: maybeContractValue) else {
                return false
            }

            if contract.sameContract(as: Constants.nullAddress) {
                return tickerId.symbol.localizedLowercase == token.symbol.localizedLowercase
            } else if contract.sameContract(as: token.contractAddress) {
                return true
            } else if token.server == .polygon && token.contractAddress == Constants.nativeCryptoAddressInDatabase && contract.sameContract(as: Self.polygonMaticContract) {
                return true
            } else {
                return token.canPassFiltering
            }
        } else {
            return tickerId.symbol.localizedLowercase == token.symbol.localizedLowercase && tickerId.name.localizedLowercase == token.name.localizedLowercase
        }
    }

    //Mapping created by examining CoinGecko API output empirically
    private func platformMatches(_ platform: String, server: RPCServer) -> Bool {
        switch server {
        case .main: return platform == "ethereum"
        case .classic: return platform == "ethereum-classic"
        case .xDai: return platform == "xdai"
        case .binance_smart_chain: return platform == "binance-smart-chain"
        case .avalanche: return platform == "avalanche"
        case .polygon: return platform == "polygon-pos"
        case .candle: return platform == "candle"
        case .fantom: return platform == "fantom"
        case .arbitrum: return platform == "arbitrum-one"
        case .klaytnCypress, .klaytnBaobabTestnet: return platform == "klay-token"
        case .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .custom, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby, .phi, .ioTeX, .ioTeXTestnet:
            return false
        }
    }

    private func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main: return true
        case .classic: return true
        case .xDai: return true
        case .binance_smart_chain: return true
        case .avalanche: return true
        case .polygon: return true
        case .candle: return true
        case .arbitrum: return true
        case .fantom: return true
        case .palm: return true
        case .klaytnCypress, .klaytnBaobabTestnet: return true
        case .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .custom, .optimistic, .optimisticKovan, .cronosTestnet, .palmTestnet, .arbitrumRinkeby, .phi, .ioTeX, .ioTeXTestnet:
            return false
        }
    }
}
