//
//  TickerId.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.03.2022.
//

import Foundation

struct TickerId: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case platforms
    }

    let id: String
    let symbol: String
    let name: String
    let platforms: [String: String]

    init(from decoder: Decoder) throws {
        enum AnyError: Swift.Error {
            case invalid
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        platforms = container.decode([String: String].self, forKey: .platforms, defaultValue: [:])
    }
}
