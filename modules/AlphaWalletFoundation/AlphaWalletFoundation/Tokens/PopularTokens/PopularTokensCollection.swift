//
//  PopularTokensCollection.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2021.
//

import Foundation
import Combine
import AlphaWalletCore

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

public struct PopularToken: Decodable {
    private enum AnyError: Error {
        case invalid
    }

    public var contractAddress: AlphaWallet.Address
    public var server: RPCServer
    public var name: String

    enum CodingKeys: String, CodingKey {
        case address
        case server = "network"
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let address = AlphaWallet.Address(uncheckedAgainstNullAddress: try container.decode(String.self, forKey: .address)) {
            contractAddress = address
        } else {
            throw AnyError.invalid
        }
        name = container.decode(String.self, forKey: .name, defaultValue: "")
        server = RPCServer(chainID: try container.decode(Int.self, forKey: .server))
    }
}

public enum WalletOrPopularToken {
    case walletToken(TokenViewModel)
    case popularToken(PopularToken)
}

public protocol PopularTokensCollectionType: AnyObject {
    func fetchTokens() -> AnyPublisher<[PopularToken], PromiseError>
}

public class PopularTokensCollection: NSObject, PopularTokensCollectionType {
    private let queue = DispatchQueue(label: "LocalPopularTokensCollection")
    private static var cachedTokens: [PopularToken]? = .none
    private let tokensUrl: URL
    private let servers: AnyPublisher<[RPCServer], Never>

    public init(servers: AnyPublisher<[RPCServer], Never>, tokensUrl: URL) {
        self.servers = servers
        self.tokensUrl = tokensUrl
    }

    public func fetchTokens() -> AnyPublisher<[PopularToken], PromiseError> {
        servers.receive(on: queue)
            .tryMap { [tokensUrl] servers -> [PopularToken] in
                if let tokens = PopularTokensCollection.cachedTokens {
                    let tokens = PopularTokensCollection.filterTokens(with: servers, in: tokens)
                    return tokens
                } else {
                    let data = try Data(contentsOf: tokensUrl, options: .alwaysMapped)
                    let response = try JSONDecoder().decode(PopularTokenList.self, from: data)

                    PopularTokensCollection.cachedTokens = response.tokens

                    return PopularTokensCollection.filterTokens(with: servers, in: response.tokens)
                }
            }.mapError { PromiseError(error: $0) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private static func filterTokens(with servers: [RPCServer], in response: [PopularToken]) -> [PopularToken] {
        return response.filter { each in servers.contains(each.server) }
    }
}

extension PopularTokensCollection {
    //Force unwraps protected by unit test — try removing to replace with dummy to see test fails
    public static var bundleLocatedTokensUrl: URL {
        let resourceBundleUrl = Bundle(for: PopularTokensCollection.self).url(forResource: String(reflecting: PopularTokensCollection.self).components(separatedBy: ".").first!, withExtension: "bundle")!
        let resourceBundle = Bundle(url: resourceBundleUrl)!
        return resourceBundle.url(forResource: "known_contract", withExtension: "json")!
    }
}

private struct PopularTokenList: Decodable {
    public var tokens: [PopularToken] = []

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONCodingKeys.self)

        for key in container.allKeys {
            tokens.append(contentsOf: try container.decode([PopularToken].self, forKey: key))
        }
    }
}
