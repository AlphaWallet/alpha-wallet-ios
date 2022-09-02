//
//  NonFungibleJsonBalanceFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletOpenSea
import BigInt
import PromiseKit
import SwiftyJSON

//TODO: think about the name, remove queue later, replace with any publisher
public class NonFungibleJsonBalanceFetcher {
    private let tokensService: TokenProvidable
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()
    private lazy var nonFungibleContract = NonFungibleContract(server: server, queue: queue)
    private let server: RPCServer
    private let queue: DispatchQueue

    public init(server: RPCServer, tokensService: TokenProvidable, queue: DispatchQueue) {
        self.server = server
        self.tokensService = tokensService
        self.queue = queue
    }

    //Misnomer, we call this "nonFungible", but this includes ERC1155 which can contain (semi-)fungibles, but there's no better name
    public func fetchNonFungibleJson(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address, enjinTokens: EnjinTokenIdsToSemiFungibles) -> Guarantee<NonFungibleBalanceAndItsSource<JsonString>> {
        firstly {
            nonFungibleContract.getTokenUri(for: tokenId, contract: address)
        }.then(on: queue, {
            self.fetchTokenJson(forTokenId: tokenId, tokenType: tokenType, uri: $0, address: address, enjinTokens: enjinTokens)
        }).recover(on: queue, { _ in
            return self.generateTokenJsonFallback(forTokenId: tokenId, tokenType: tokenType, address: address)
        })
    }

    private func generateTokenJsonFallback(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address) -> Guarantee<NonFungibleBalanceAndItsSource<JsonString>> {
        var jsonDictionary = JSON()
        if let token = tokensService.token(for: address, server: server) {
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
        return .value(.init(tokenId: tokenId, value: json, source: .fallback))
    }

    private func fetchTokenJson(forTokenId tokenId: String, tokenType: TokenType, uri originalUri: URL, address: AlphaWallet.Address, enjinTokens: EnjinTokenIdsToSemiFungibles) -> Promise<NonFungibleBalanceAndItsSource<JsonString>> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")
        let server = server
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData(queue: queue)
        }.map(on: queue, { [tokensService] (data, _) -> NonFungibleBalanceAndItsSource in
            if let json = try? JSON(data: data) {
                if let errorMessage = json["error"].string {
                    warnLog("Fetched token URI: \(originalUri.absoluteString) error: \(errorMessage)")
                }
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    verboseLog("Fetched token URI: \(originalUri.absoluteString)")
                    var jsonDictionary = json
                    if let token = tokensService.token(for: address, server: server) {
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
                    let tokenIdSubstituted = TokenIdConverter.toTokenIdSubstituted(string: tokenId)
                    if let enjinToken = enjinTokens[tokenIdSubstituted] {
                        jsonDictionary.update(enjinToken: enjinToken)
                    }

                    if let jsonString = jsonDictionary.rawString() {
                        return .init(tokenId: tokenId, value: jsonString, source: .uri(uri))
                    } else {
                        throw Error()
                    }
                }
            } else {
                //TODO lots of this so not using `warnLog()`. Check
                verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                throw Error()
            }
        }).recover { error -> Promise<NonFungibleBalanceAndItsSource> in
            //TODO lots of this so not using `warnLog()`. Check
            verboseLog("Fetching token URI: \(originalUri) error: \(error)")
            throw error
        }
    }
}
