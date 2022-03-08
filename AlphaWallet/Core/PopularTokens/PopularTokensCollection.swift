//
//  PopularTokensCollection.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2021.
//

import Foundation
import PromiseKit

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

struct PopularToken: Decodable {
    private enum AnyError: Error {
        case invalid
    }

    var contractAddress: AlphaWallet.Address
    var server: RPCServer
    var name: String

    var iconImage: Subscribable<TokenImage> {
        return TokenImageFetcher.instance.image(contractAddress: contractAddress, server: server, name: name, size: .s120)
    }

    enum CodingKeys: String, CodingKey {
        case address
        case server = "network"
        case name
    }

    init(from decoder: Decoder) throws {
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

enum WalletOrPopularToken {
    case walletToken(TokenObject)
    case popularToken(PopularToken)
}

protocol PopularTokensCollectionType: AnyObject {
    func fetchTokens() -> Promise<[PopularToken]>
}

class PopularTokensCollection: NSObject, PopularTokensCollectionType {
    private let tokensURL: URL = URL(string: "https://raw.githubusercontent.com/AlphaWallet/alpha-wallet-android/fa86b477586929f61e7fefefc6a9c70de91de1f0/app/src/main/assets/known_contract.json")!
    private let queue = DispatchQueue.global()
    private static var cache: [PopularToken]? = .none

    func fetchTokens() -> Promise<[PopularToken]> {
        if let cache = Self.cache {
            return .value(cache)
        } else {
            return Promise { seal in
                queue.async {
                    do {
                        let data = try Data(contentsOf: self.tokensURL, options: .alwaysMapped)
                        let response = try JSONDecoder().decode(PopularTokenList.self, from: data)

                        Self.cache = response.tokens

                        seal.fulfill(response.tokens)
                    } catch {
                        seal.reject(error)
                    }
                }
            }
        }
    }
}

class LocalPopularTokensCollection: NSObject, PopularTokensCollectionType {
    private let tokensURL: URL = URL(fileURLWithPath: Bundle.main.path(forResource: "known_contract", ofType: "json")!)
    private let queue = DispatchQueue.global()
    private static var cache: [PopularToken]? = .none

    func fetchTokens() -> Promise<[PopularToken]> {
        if let cache = Self.cache {
            return .value(cache)
        } else {
            return Promise { seal in
                queue.async {
                    do {
                        let data = try Data(contentsOf: self.tokensURL, options: .alwaysMapped)
                        let response = try JSONDecoder().decode(PopularTokenList.self, from: data)

                        Self.cache = response.tokens

                        seal.fulfill(response.tokens)
                    } catch {
                        seal.reject(error)
                    }
                }
            }
        }
    }
}

private struct PopularTokenList: Decodable {
    var tokens: [PopularToken] = []

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONCodingKeys.self)

        for key in container.allKeys {
            tokens.append(contentsOf: try container.decode([PopularToken].self, forKey: key))
        }
    }
}
