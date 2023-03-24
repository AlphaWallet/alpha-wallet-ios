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

enum LoaderTask<T> {
    case inProgress(Task<T, Error>)
    case fetched(T)
}

final actor JsonFromTokenUri {
    typealias Publisher = AnyPublisher<NonFungibleBalanceAndItsSource<JsonString>, SessionTaskError>

    private let tokensService: TokenProvidable
    private let getTokenUri: NonFungibleContract
    private let blockchainProvider: BlockchainProvider
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private let networkService: NetworkService
    private var inFlightTasks: [String: LoaderTask<NonFungibleBalanceAndItsSource<JsonString>>] = [:]

    public init(blockchainProvider: BlockchainProvider,
                tokensService: TokenProvidable,
                networkService: NetworkService) {

        self.networkService = networkService
        self.blockchainProvider = blockchainProvider
        self.tokensService = tokensService
        self.getTokenUri = NonFungibleContract(
            blockchainProvider: blockchainProvider,
            uriMapper: TokenUriMapper(hostMappers: [
                HostBasedTokenUriMapper(host: "api.mintkudos.xyz"),
                HostBasedTokenUriMapper(host: "api.walletads.io"),
                HostBasedTokenUriMapper(host: "gateway.pinata.cloud")
            ]))
    }

    func fetchJsonFromTokenUri(for tokenId: String,
                               tokenType: NonFungibleFromJsonTokenType,
                               address: AlphaWallet.Address) async throws -> NonFungibleBalanceAndItsSource<JsonString> {

        let key = "\(tokenId).\(address.eip55String).\(tokenType.rawValue)"
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<NonFungibleBalanceAndItsSource<JsonString>, Error> = Task {
            do {
                let data = try await getTokenUri.getUriOrTokenUri(for: tokenId, contract: address)
                return try await handleUriData(data: data, tokenId: tokenId, tokenType: tokenType, address: address)
            } catch {
                return try await generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
            }
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }

    private func handleUriData(data: TokenUriData,
                               tokenId: String,
                               tokenType: NonFungibleFromJsonTokenType,
                               address: AlphaWallet.Address) async throws -> NonFungibleBalanceAndItsSource<JsonString> {

        switch data {
        case .uri(let uri):
            return try await fetchTokenJson(for: tokenId, tokenType: tokenType, uri: uri, address: address)
        case .string(let str):
            return try await generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        case .json(let json):
            return try fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: nil, address: address)
        case .data(let data):
            return try await generateTokenJsonFallback(for: tokenId, tokenType: tokenType, address: address)
        }
    }

    private func generateTokenJsonFallback(for tokenId: String,
                                           tokenType: NonFungibleFromJsonTokenType,
                                           address: AlphaWallet.Address) async throws -> NonFungibleBalanceAndItsSource<JsonString> {
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
        return .init(tokenId: tokenId, value: json, source: .fallback)
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
            if let token = tokensService.token(for: address, server: blockchainProvider.server) {
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
                                address: AlphaWallet.Address) async throws -> NonFungibleBalanceAndItsSource<JsonString> {
        
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")

        do {
            let data = try await networkService.dataTask(UrlRequest(url: uri))
            if let json = try? JSON(data: data.data) {
                return try self.fulfill(json: json, tokenId: tokenId, tokenType: tokenType, uri: uri, address: address)
            } else {
                //TODO lots of this so not using `warnLog()`. Check
                verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                throw SessionTaskError(error: JsonFromTokenUriError(message: "Decode json failure for: \(tokenId) \(address) \(originalUri)"))
            }
        } catch {
            verboseLog("Fetching token URI: \(originalUri) error: \(error)")
            throw SessionTaskError(error: error)
        }
    }
}
