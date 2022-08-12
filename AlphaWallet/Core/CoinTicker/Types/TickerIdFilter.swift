//
//  TickerIdFilter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

class TickerIdFilter {

    //https://polygonscan.com/address/0x0000000000000000000000000000000000001010
    static private let polygonMaticContract = AlphaWallet.Address(string: "0x0000000000000000000000000000000000001010")!

    func tickerId(for token: TokenMappedToTicker, in tickerIds: [TickerId]) -> TickerIdString? {
        return tickerIds.first(where: { filterMathesInPlatforms(token: token, tickerId: $0) }).flatMap { $0.id }
    }
    
    private func filterMathesInPlatforms(token: TokenMappedToTicker, tickerId: TickerId) -> Bool {
        func isMatchingSymbolAndName(token: TokenMappedToTicker, tickerId: TickerId) -> Bool {
            tickerId.symbol.localizedLowercase == token.symbol.localizedLowercase && tickerId.name.localizedLowercase == token.name.localizedLowercase
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
            if contract.address.sameContract(as: Constants.nullAddress) {
                return tickerId.symbol.localizedLowercase == token.symbol.localizedLowercase
            } else if contract.address.sameContract(as: token.contractAddress) {
                return true
            } else if token.server == .polygon && token.contractAddress == Constants.nativeCryptoAddressInDatabase && contract.address.sameContract(as: Self.polygonMaticContract) {
                return true
            } else {
                return false
            }
        } else {
            return isMatchingSymbolAndName(token: token, tickerId: tickerId)
        }
    }
}
