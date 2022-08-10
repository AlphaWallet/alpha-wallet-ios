//
//  TokenMappedToTicker.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

struct TokenMappedToTicker {
    let symbol: String
    let name: String
    let contractAddress: AlphaWallet.Address
    let server: RPCServer
    /// Already found ticker id, out of info.coingeckoTickerId
    let coinGeckoId: String?

    var knownCoinGeckoTickerId: String? {
        if let tickerId = coinGeckoId {
            return tickerId
        } else if server == .avalanche && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "avalanche-2"
        } else if server == .fantom && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "fantom"
        } else if server == .binance_smart_chain && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "binancecoin"
        } else if server == .klaytnCypress && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "klay-token"
        } else if server == .xDai && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "gnosis"
        } else if server == .arbitrum && contractAddress == Constants.nativeCryptoAddressInDatabase {
            return "ethereum"
        } else {
            return nil
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(contractAddress.eip55String)
        hasher.combine(server.chainID)
    }
}

extension TokenMappedToTicker: Hashable, Codable {

    init(token: Token) {
        symbol = token.symbol
        name = token.name
        contractAddress = token.contractAddress
        server = token.server
        coinGeckoId = token.info.coinGeckoId
    } 
}

extension TokenMappedToTicker: Equatable {

    /// Checks for matching of ticker id
    public static func == (lhs: TokenMappedToTicker, rhs: AddressAndRPCServer) -> Bool {
        return lhs.contractAddress.sameContract(as: rhs.address) && lhs.server == rhs.server
    }
}
