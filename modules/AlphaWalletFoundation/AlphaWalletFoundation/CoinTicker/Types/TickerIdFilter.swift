//
//  TickerIdFilter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

public class TickerIdFilter {
    //TODO remove if we don't use it for debugging anymore
    //Used during development to observe how often positive matching happens when platforms don't match, to see how many potential false positives get. Eg. https://candleexplorer.com/address/0x6Ee592139e9DD84587a32831A33a32202d1f0F12 would match USDC with price = $1 because name = "USDC" and symbol = "USDC", but anyone can create such a token on any chain
    public static var matchCounts: [String: Int] = [:]

    //https://polygonscan.com/address/0x0000000000000000000000000000000000001010
    static private let polygonMaticContract = AlphaWallet.Address(string: "0x0000000000000000000000000000000000001010")!

    func tickerIdObject(for token: TokenMappedToTicker, in tickerIds: [TickerId]) -> TickerIdString? {
        return tickerIds.first(where: { filterMathesInPlatforms(token: token, tickerId: $0) }).flatMap { $0.id }
    }

    private func filterMathesInPlatforms(token: TokenMappedToTicker, tickerId: TickerId) -> Bool {
        func isMatchingSymbolAndName(token: TokenMappedToTicker, tickerId: TickerId) -> Bool {
            let result = tickerId.symbol.compare(token.symbol, options: .caseInsensitive) == .orderedSame && tickerId.name.compare(token.name, options: .caseInsensitive) == .orderedSame
            if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) && result {
                Self.matchCounts["by symbol+name, ignoring platform", default: 0] += 1
            }
            //Logging enabled has a side effect. This matching regardless of platform will be applied. Otherwise the counts logged will be incorrect
            if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) && result {
                return result
            } else {
                //Force is so we no longer match by ignoring the platform, this produces false positives. Eg. https://candleexplorer.com/address/0x6Ee592139e9DD84587a32831A33a32202d1f0F12 would match USDC with price = $1 because name = "USDC" and symbol = "USDC", but anyone can create such a token on any chain
                return false
            }
        }

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

        if let contract = tickerId.platforms.first(where: { $0.server == token.server }) {
            if contract.address == Constants.nullAddress {
                let result = tickerId.symbol.compare(token.symbol, options: .caseInsensitive) == .orderedSame
                if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) && result {
                    Self.matchCounts["by platform+symbol for 0x0", default: 0] += 1
                }
                return result
            } else if contract.address == token.contractAddress {
                if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) {
                    Self.matchCounts["by platform+contract", default: 0] += 1
                }
                return true
            } else if token.server == .polygon && token.contractAddress == Constants.nativeCryptoAddressInDatabase && contract.address == Self.polygonMaticContract {
                if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) {
                    Self.matchCounts["by platform + Polygon 0x0 = Matic contract", default: 0] += 1
                }
                return true
            } else {
                return false
            }
        } else {
            return isMatchingSymbolAndName(token: token, tickerId: tickerId)
        }
    }

    func filterMathesInPlatforms(token: TokenMappedToTicker, tickerId object: TickerIdObject) -> Bool {
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

        if let platform = object.platforms.first(where: { $0.server == token.server }) {
            if platform.contractAddress == Constants.nullAddress {
                return object.symbol.compare(token.symbol, options: .caseInsensitive) == .orderedSame
            } else if platform.contractAddress == token.contractAddress {
                return true
            } else if token.server == .polygon && token.contractAddress == Constants.nativeCryptoAddressInDatabase && platform.contractAddress == Self.polygonMaticContract {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}
