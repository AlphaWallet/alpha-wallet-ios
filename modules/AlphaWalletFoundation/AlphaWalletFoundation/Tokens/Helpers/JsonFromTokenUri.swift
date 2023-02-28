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
    typealias Publisher = AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>

    private let tokensService: TokenProvidable
    private let getTokenUri: NonFungibleContract
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromises: [String: Publisher] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.jsonFromTokenUri")
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private let networkService: NetworkService

    public init(blockchainProvider: BlockchainProvider,
                tokensService: TokenProvidable,
                networkService: NetworkService) {

        self.networkService = networkService
        self.blockchainProvider = blockchainProvider
        self.tokensService = tokensService
        self.getTokenUri = NonFungibleContract(blockchainProvider: blockchainProvider)
    }

    func clear() {
        inFlightPromises.removeAll()
    }

    func fetchJsonFromTokenUri(for tokenId: String,
                               tokenType: TokenType,
                               address: AlphaWallet.Address) -> Publisher {

        return Just(tokenId)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, weak getTokenUri] tokenId -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> in
                guard let strongSelf = self, let getTokenUri = getTokenUri else { return .empty() }
                let key = "\(tokenId).\(address.eip55String).\(tokenType.rawValue)"

                if let promise = strongSelf.inFlightPromises[key] {
                    return promise
                } else {
                    let promise = getTokenUri.getUriOrTokenUri(for: tokenId, contract: address)
                        .flatMap { strongSelf.handleUriData(data: $0, tokenId: tokenId, tokenType: tokenType, address: address) }
                        .catch { _ in return strongSelf.generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address) }
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in strongSelf.inFlightPromises[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    strongSelf.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }

    private func handleUriData(data: TokenUriData,
                               tokenId: String,
                               tokenType: TokenType,
                               address: AlphaWallet.Address) -> Publisher {

        switch data {
        case .uri(let uri):
            return fetchTokenJson(for: tokenId, tokenType: tokenType, uri: uri, address: address)
        case .string(let str):
            return generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        case .json(let json):
            do {
                let value = try fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: nil, address: address)
                return .just(value)
            } catch {
                return .fail(SessionTaskError(error: error))
            }
        case .data(let data):
            return generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        }
    }

    private func generateTokenJsonFallback(for tokenId: String,
                                           tokenType: TokenType,
                                           address: AlphaWallet.Address) -> Publisher {
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
            jsonDictionary["animationUrl"] = ""
        }
        let json = jsonDictionary.rawString()!
        return .just(.init(tokenId: tokenId, value: json, source: .fallback))
    }

    struct JsonFromTokenUriError: Swift.Error {
        let message: String
    }

    private func fulfill(json: JSON,
                         tokenId: String,
                         tokenType: TokenType,
                         uri originalUri: URL?,
                         address: AlphaWallet.Address) throws -> NonFungibleBalanceAndItsSource<JsonString> {

        if let errorMessage = json["error"].string {
            warnLog("Fetched token URI: \(originalUri?.absoluteString) error: \(errorMessage)")
        }

        if json["error"] == "Internal Server Error" {
            throw SessionTaskError(error: JsonFromTokenUriError(message: json["error"].stringValue))
        } else {
            verboseLog("Fetched token URI: \(originalUri?.absoluteString)")
            var jsonDictionary = json
            if let token = tokensService.token(for: address, server: blockchainProvider.server) {
                jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
                    //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                jsonDictionary["contractName"] = JSON(token.name)
                jsonDictionary["symbol"] = JSON(token.symbol)
                jsonDictionary["tokenId"] = JSON(tokenId)
                jsonDictionary["decimals"] = JSON(json["decimals"].intValue)
                jsonDictionary["name"] = JSON(json["name"].stringValue)
                jsonDictionary["imageUrl"] = JSON(json["image"].string ?? json["image_url"].string ?? "")
                jsonDictionary["thumbnailUrl"] = json["imageUrl"]
                    //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                jsonDictionary["externalLink"] = JSON(json["home_url"].string ?? json["external_url"].string ?? "")
                jsonDictionary["animationUrl"] = JSON(jsonDictionary["animation_url"].stringValue)
            }

            if let jsonString = jsonDictionary.rawString() {
                let source = originalUri.flatMap { NonFungibleBalance.Source.uri($0) } ?? .undefined
                return .init(tokenId: tokenId, value: jsonString, source: source)
            } else {
                throw SessionTaskError(error: JsonFromTokenUriError(message: "Decode json from \(jsonDictionary.debugDescription) failure for: \(tokenId) \(address) \(originalUri)"))
            }
        }
    }

    private func fetchTokenJson(for tokenId: String,
                                tokenType: TokenType,
                                uri originalUri: URL,
                                address: AlphaWallet.Address) -> Publisher {
        
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")

        return networkService
            .dataTaskPublisher(UrlRequest(url: uri))
            .flatMap { data -> Publisher in
                if let json = try? JSON(data: data.data) {
                    do {
                        return .just(try self.fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: uri, address: address))
                    } catch {
                        verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                        return .fail(.responseError(error))
                    }
                } else {
                    //TODO lots of this so not using `warnLog()`. Check
                    verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                    return .fail(.responseError(JsonFromTokenUriError(message: "Decode json failure for: \(tokenId) \(address) \(originalUri)")))
                }
            }.handleEvents(receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                verboseLog("Fetching token URI: \(originalUri) error: \(error)")
            }).eraseToAnyPublisher()
    }
}
