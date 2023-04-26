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
import BigInt

final class JsonFromTokenUri {
    typealias Publisher = AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>

    private let tokensDataStore: TokensDataStore
    private let getTokenUri: NonFungibleContract
    private let blockchainProvider: BlockchainProvider
    private var inFlightPublishers: [String: Publisher] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.jsonFromTokenUri")
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

    func clear() {
        inFlightPublishers.removeAll()
    }

    func fetchJsonFromTokenUri(for tokenId: String,
                               tokenType: NonFungibleFromJsonTokenType,
                               address: AlphaWallet.Address) -> Publisher {

        return Just(tokenId)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, weak getTokenUri] tokenId -> AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError> in
                guard let strongSelf = self, let getTokenUri = getTokenUri else { return .empty() }
                let key = "\(tokenId).\(address.eip55String).\(tokenType.rawValue)"

                if let publisher = strongSelf.inFlightPublishers[key] {
                    return publisher
                } else {
                    let publisher = getTokenUri.getUriOrTokenUri(for: tokenId, contract: address)
                        .breakpoint(receiveOutput: { value in
                            guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                            print("xxx.getUriOrTokenUri: \(value)")
                            return false
                        }, receiveCompletion: { res in
                            guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                            print("xxx.getUriOrTokenUri: \(res)")
                            return false
                        })
                        .receive(on: queue)
                        .flatMap { strongSelf.handleUriData(data: $0, tokenId: tokenId, tokenType: tokenType, address: address) }
                        .catch { _ in return strongSelf.generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address) }
                        .handleEvents(receiveCompletion: { _ in strongSelf.inFlightPublishers[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    strongSelf.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.breakpoint(receiveOutput: { value in
                guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                print("xxx.fetchJsonFromTokenUri: \(value)")
                return false
            }, receiveCompletion: { res in
                guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                print("xxx.fetchJsonFromTokenUri: \(res)")
                return false
            }).eraseToAnyPublisher()
    }

    private func handleUriData(data: TokenUriData,
                               tokenId: String,
                               tokenType: NonFungibleFromJsonTokenType,
                               address: AlphaWallet.Address) -> Publisher {

        switch data {
        case .uri(let uri):
            let uri = uriMapper.map(uri: uri) ?? uri
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
                                           tokenType: NonFungibleFromJsonTokenType,
                                           address: AlphaWallet.Address) -> Publisher {
        var jsonDictionary = JSON()
        if let token = tokensDataStore.token(for: address, server: blockchainProvider.server) {
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
                         tokenType: NonFungibleFromJsonTokenType,
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
            if let token = tokensDataStore.token(for: address, server: blockchainProvider.server) {
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
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")

        return transporter
            .dataPublisher(UrlRequest(url: uri))
            .breakpoint(receiveOutput: { value in
                guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                print("xxx.fetchTokenJson: \(value)")
                return false
            }, receiveCompletion: { res in
                guard address.eip55String == "0xC9419ebd3DcBdFf2FaD35a8e13AcA24C26E9A38d" else { return false }
                print("xxx.fetchTokenJson: \(res)")
                return false
            })
            .receive(on: queue)
            .flatMap { response -> Publisher in
                if let data = response.data, let json = try? JSON(data: data) {
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
