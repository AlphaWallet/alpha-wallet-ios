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
import AlphaWalletWeb3
import SwiftyJSON
import Combine
import BigInt

final class JsonFromTokenUri {
    typealias Publisher = AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>

    private let tokensDataStore: TokensDataStore
    private let getTokenUri: NonFungibleContract
    private let blockchainProvider: BlockchainProvider
    private var inFlightPublishers: [String: Publisher] = [:]
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private let transporter: ApiTransporter
    private let uriMapper: TokenUriMapper

    public init(blockchainProvider: BlockchainProvider,
                tokensDataStore: TokensDataStore,
                transporter: ApiTransporter) {

        self.transporter = transporter
        self.blockchainProvider = blockchainProvider
        self.tokensDataStore = tokensDataStore
        self.getTokenUri = NonFungibleContract(blockchainProvider: blockchainProvider)
        self.uriMapper = TokenUriMapper(hostMappers: [
            HostBasedTokenUriMapper(host: "api.mintkudos.xyz"),
            HostBasedTokenUriMapper(host: "api.walletads.io"),
            HostBasedTokenUriMapper(host: "gateway.pinata.cloud")
        ])
    }

    deinit {
        clear()
    }

    private func clear() {
        inFlightPublishers.removeAll()
    }

    func fetchJsonFromTokenUri(for tokenId: String,
                               tokenType: NonFungibleFromJsonTokenType,
                               address: AlphaWallet.Address) -> Publisher {

        return Just(tokenId)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, weak getTokenUri] tokenId -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> in
                guard let strongSelf = self, let getTokenUri = getTokenUri else { return .empty() }
                let key = "\(tokenId).\(address.eip55String).\(tokenType.rawValue)"

                if let publisher = strongSelf.inFlightPublishers[key] {
                    return publisher
                } else {
                    let publisher = getTokenUri.getUriOrTokenUri(for: tokenId, contract: address)
                        .flatMap { strongSelf.handleUriData(data: $0, tokenId: tokenId, tokenType: tokenType, address: address) }
                        .catch { _ in return strongSelf.generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address) }
                        .handleEvents(receiveCompletion: { _ in strongSelf.inFlightPublishers[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    strongSelf.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.eraseToAnyPublisher()
    }

    private func handleUriData(data: TokenUriData, tokenId: String, tokenType: NonFungibleFromJsonTokenType, address: AlphaWallet.Address) -> Publisher {
        switch data {
        case .uri(let uri):
            let uri = uriMapper.map(uri: uri) ?? uri
            return fetchTokenJson(for: tokenId, tokenType: tokenType, uri: uri, address: address)
        case .string(let str):
            return generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        case .json(let json):
            return asFutureThrowable {
                do {
                    return try await self.fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: nil, address: address)
                } catch {
                    throw SessionTaskError(error: error)
                }
            }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
        case .data(let data):
            return generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        }
    }

    private func generateTokenJsonFallback(for tokenId: String, tokenType: NonFungibleFromJsonTokenType, address: AlphaWallet.Address) -> Publisher {
        let subject = PassthroughSubject<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>()
        Task { @MainActor in
            var jsonDictionary = JSON()
            if let token = await tokensDataStore.token(for: address, server: blockchainProvider.server) {
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
            subject.send(.init(tokenId: tokenId, value: json, source: .fallback))
        }
        return subject.eraseToAnyPublisher()
    }

    struct JsonFromTokenUriError: Swift.Error {
        let message: String
    }

    private func fulfill(json: JSON, tokenId: String, tokenType: NonFungibleFromJsonTokenType, uri originalUri: URL?, address: AlphaWallet.Address) async throws -> NonFungibleBalanceAndItsSource<JsonString> {
        if let errorMessage = json["error"].string {
            warnLog("Fetched token URI: \(originalUri?.absoluteString) error: \(errorMessage)")
        }

        if json["error"] == "Internal Server Error" {
            throw SessionTaskError(error: JsonFromTokenUriError(message: json["error"].stringValue))
        } else {
            verboseLog("Fetched token URI: \(originalUri?.absoluteString)")

            var jsonDictionary = json
            if let token = await tokensDataStore.token(for: address, server: blockchainProvider.server) {
                jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
                    //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                jsonDictionary["contractName"] = JSON(token.name)
                jsonDictionary["symbol"] = JSON(token.symbol)
                jsonDictionary["tokenId"] = JSON(tokenId)
                jsonDictionary["decimals"] = JSON(json["decimals"].intValue)
                jsonDictionary["name"] = JSON(json["name"].stringValue)
                jsonDictionary["imageUrl"] = JSON(json["image"].string ?? json["image_url"].stringValue)
                jsonDictionary["thumbnailUrl"] = JSON(json["thumbnail_url"].string ?? json["imageUrl"].stringValue)
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
                                tokenType: NonFungibleFromJsonTokenType,
                                uri originalUri: URL,
                                address: AlphaWallet.Address) -> Publisher {

        let uri = originalUri.rewrittenIfIpfs
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")
        return asFutureThrowable {
            let response = try await self.transporter.dataTask(UrlRequest(url: uri))
            if let json = try? JSON(data: response.data) {
                do {
                    return try await self.fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: uri, address: address)
                } catch {
                    verboseLog("Fetching token URI: \(originalUri) error: \(error)")
                    throw SessionTaskError.responseError(error)
                }
            } else {
                verboseLog("Fetching token URI: \(originalUri) error")
                throw SessionTaskError.responseError(JsonFromTokenUriError(message: "Decode json failure for: \(tokenId) \(address) \(originalUri)"))
            }
        }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
    }
}
