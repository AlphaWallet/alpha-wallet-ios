//
//  JsonFromTokenUri.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2022.
//

import Foundation
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletOpenSea
import SwiftyJSON
import Combine

final class JsonFromTokenUri {
    private let tokensService: TokenProvidable
    private lazy var getTokenUri = NonFungibleContract(blockchainProvider: blockchainProvider)
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromises: [String: AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.jsonFromTokenUri")
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private let networkService: NetworkService

    public init(blockchainProvider: BlockchainProvider, tokensService: TokenProvidable, networkService: NetworkService) {
        self.networkService = networkService
        self.blockchainProvider = blockchainProvider
        self.tokensService = tokensService
    }

    func fetchJsonFromTokenUri(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address, enjinToken: GetEnjinTokenQuery.Data.EnjinToken?) -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> {
        return Just(tokenId)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [queue, getTokenUri] tokenId -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> in
                let key = "\(tokenId).\(address.eip55String).\(tokenType.rawValue)"

                if let promise = self.inFlightPromises[key] {
                    return promise
                } else {
                    let promise = getTokenUri.getUriOrTokenUri(for: tokenId, contract: address)
                        .flatMap { self.fetchTokenJson(forTokenId: tokenId, tokenType: tokenType, uri: $0, address: address, enjinToken: enjinToken) }
                        .catch { _ in return self.generateTokenJsonFallback(forTokenId: tokenId, tokenType: tokenType, address: address) }
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in self.inFlightPromises[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    self.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }

    private func generateTokenJsonFallback(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address) -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> {
        var jsonDictionary = JSON()
        if let token = tokensService.token(for: address, server: blockchainProvider.server) {
            jsonDictionary["tokenId"] = JSON(tokenId)
            jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
            jsonDictionary["contractName"] = JSON(token.name)
            jsonDictionary["decimals"] = JSON(0)
            jsonDictionary["symbol"] = JSON(token.symbol)
            jsonDictionary["name"] = ""
            jsonDictionary["imageUrl"] = ""
            jsonDictionary["thumbnailUrl"] = ""
            jsonDictionary["externalLink"] = ""
        }
        let json = jsonDictionary.rawString()!
        return .just(.init(tokenId: tokenId, value: json, source: .fallback))
    }

    private func fetchTokenJson(forTokenId tokenId: String, tokenType: TokenType, uri originalUri: URL, address: AlphaWallet.Address, enjinToken: GetEnjinTokenQuery.Data.EnjinToken?) -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")

        //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
        return networkService
            .dataTaskPublisher(UrlRequest(url: uri))
            .flatMap { [tokensService, blockchainProvider] data -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> in
                if let json = try? JSON(data: data.data) {
                    if let errorMessage = json["error"].string {
                        warnLog("Fetched token URI: \(originalUri.absoluteString) error: \(errorMessage)")
                    }
                    if json["error"] == "Internal Server Error" {
                        return .fail(.responseError(Error()))
                    } else {
                        verboseLog("Fetched token URI: \(originalUri.absoluteString)")
                        var jsonDictionary = json
                        if let token = tokensService.token(for: address, server: blockchainProvider.server) {
                            jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
                            //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                            jsonDictionary["contractName"] = JSON(token.name)
                            jsonDictionary["symbol"] = JSON(token.symbol)
                            jsonDictionary["tokenId"] = JSON(tokenId)
                            jsonDictionary["decimals"] = JSON(jsonDictionary["decimals"].intValue)
                            jsonDictionary["name"] = JSON(jsonDictionary["name"].stringValue)
                            jsonDictionary["imageUrl"] = JSON(jsonDictionary["image"].string ?? jsonDictionary["image_url"].string ?? "")
                            jsonDictionary["thumbnailUrl"] = jsonDictionary["imageUrl"]
                            //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                            jsonDictionary["externalLink"] = JSON(jsonDictionary["home_url"].string ?? jsonDictionary["external_url"].string ?? "")
                        }

                        if let enjinToken = enjinToken {
                            jsonDictionary.update(enjinToken: enjinToken)
                        }

                        if let jsonString = jsonDictionary.rawString() {
                            return .just(.init(tokenId: tokenId, value: jsonString, source: .uri(uri)))
                        } else {
                            return .fail(.responseError(Error()))
                        }
                    }
                } else {
                    //TODO lots of this so not using `warnLog()`. Check
                    verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                    return .fail(.responseError(Error()))
                }
            }.handleEvents(receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                verboseLog("Fetching token URI: \(originalUri) error: \(error)")
            }).eraseToAnyPublisher()
    }
}
