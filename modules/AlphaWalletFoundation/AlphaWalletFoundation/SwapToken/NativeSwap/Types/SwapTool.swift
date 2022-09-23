//
//  SwapTool.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import Foundation

struct SwapToolsResponse {
    let tools: [SwapTool]
}

public struct SwapTool {
    public let key: String
    public let name: String
    public let logoUrl: String
}

extension SwapToolsResponse: Decodable {
    private enum Keys: String, CodingKey {
        case tools = "bridges"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        tools = try container.decode([SwapTool].self, forKey: .tools)
    }
}
extension SwapTool: Decodable, Equatable {
    public static func == (lhs: SwapTool, rhs: SwapTool) -> Bool {
        lhs.key == rhs.key && lhs.name == rhs.name && lhs.logoUrl == rhs.logoUrl
    }
    
    private enum Keys: String, CodingKey {
        case key
        case name
        case logoUrl = "logoURI"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        key = try container.decode(String.self, forKey: .key)
        name = try container.decode(String.self, forKey: .name)
        logoUrl = try container.decode(String.self, forKey: .logoUrl)
    }
}
