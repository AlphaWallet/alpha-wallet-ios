//
//  RampAssetsResponse.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import Foundation

struct RampError: Error {}

struct RampAssetsResponse {
    let assets: [Asset]
}

public struct Asset {
    let symbol: String
    let address: AlphaWallet.Address?
    let name: String
    let decimals: Int
}

extension RampAssetsResponse: Codable {}

extension Asset: Codable {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case address
        case name
        case decimals
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .address) {
            address = AlphaWallet.Address(string: value)
        } else {
            address = .none
        }

        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        decimals = try container.decode(Int.self, forKey: .decimals)
    }

}
