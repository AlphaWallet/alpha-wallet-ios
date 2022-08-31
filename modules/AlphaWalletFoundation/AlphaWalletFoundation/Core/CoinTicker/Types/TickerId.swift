//
//  TickerId.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

public struct TickerId: Codable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let platforms: [AddressAndRPCServer]
}

extension TickerId {
    private enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case platforms
    }

    public init(from decoder: Decoder) throws {
        enum AnyError: Swift.Error {
            case invalid
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)

        do {
            var platforms: [AddressAndRPCServer] = []
            for each in try container.decode([String: String].self, forKey: .platforms) {
                guard let server = RPCServer(coinGeckoPlatform: each.key.trimmed) else { continue }
                let address: AlphaWallet.Address
                let possibleAddressValue = each.value.trimmed
                if possibleAddressValue.isEmpty {
                    address = Constants.nullAddress
                } else {
                    guard let _address = AlphaWallet.Address(string: possibleAddressValue) else { continue }
                    address = _address
                }
                platforms.append(.init(address: address, server: server))
            }

            self.platforms = platforms
        } catch {
            self.platforms = container.decode([AddressAndRPCServer].self, forKey: .platforms, defaultValue: [])
        }
    }
}

extension RPCServer {

    init?(coinGeckoPlatform: String) {
        switch coinGeckoPlatform {
        case "ethereum": self = .main
        case "ethereum-classic": self = .classic
        case "xdai": self = .xDai
        case "binance-smart-chain": self = .binance_smart_chain
        case "avalanche": self = .avalanche
        case "polygon-pos": self = .polygon
        case "fantom": self = .fantom
        case "arbitrum-one": self = .arbitrum
        case "klay-token": self = .klaytnCypress
        default: return nil
        }
    }
}
