// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

final class NonFungibleContract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        firstly {
            self.getTokenUri(for: tokenId, contract: contract)
        }.recover { _ in
            self.getUri(for: tokenId, contract: contract)
        }
    }

    private func getTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        blockchainProvider
            .callPromise(Erc721TokenUriRequest(contract: contract, tokenId: tokenId))
            .get {
                print("xxx.Erc721 tokenUri value: \($0)")
            }.recover { e -> Promise<URL> in
                print("xxx.Erc721 tokenUri failure: \(e)")
                throw e
            }
    }

    private func getUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        blockchainProvider
            .callPromise(Erc721UriRequest(contract: contract, tokenId: tokenId))
            .get {
                print("xxx.Erc721 uri value: \($0)")
            }.recover { e -> Promise<URL> in
                print("xxx.Erc721 uri failure: \(e)")
                throw e
            }
    }
}

struct Erc721TokenUriRequest: ContractMethodCall {
    typealias Response = URL

    private let function = GetTokenUri()
    private let tokenId: String
    
    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }
    var parameters: [AnyObject] { [tokenId] as [AnyObject] }

    init(contract: AlphaWallet.Address, tokenId: String) {
        self.contract = contract
        self.tokenId = tokenId
    }

    func response(from resultObject: Any) throws -> URL {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        if let string = dictionary["0"] as? String, let url = URL(string: string.stringWithTokenIdSubstituted(tokenId)) {
            return url
        } else {
            throw CastError(actualValue: dictionary["0"], expectedType: URL.self)
        }
    }
}

struct Erc721UriRequest: ContractMethodCall {
    typealias Response = URL

    private let function = GetUri()
    private let tokenId: String

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }
    var parameters: [AnyObject] { [tokenId] as [AnyObject] }

    init(contract: AlphaWallet.Address, tokenId: String) {
        self.contract = contract
        self.tokenId = tokenId
    }

    func response(from resultObject: Any) throws -> URL {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        if let string = dictionary["0"] as? String, let url = URL(string: string.stringWithTokenIdSubstituted(tokenId)) {
            return url
        } else {
            throw CastError(actualValue: dictionary["0"], expectedType: URL.self)
        }
    }
}

extension String {
    fileprivate func stringWithTokenIdSubstituted(_ tokenId: String) -> String {
        //According to https://eips.ethereum.org/EIPS/eip-1155
        //The string format of the substituted hexadecimal ID MUST be lowercase alphanumeric: [0-9a-f] with no 0x prefix.
        //The string format of the substituted hexadecimal ID MUST be leading zero padded to 64 hex characters length if necessary.
        if let tokenId = BigInt(tokenId) {
            let hex = String(tokenId, radix: 16).padding(toLength: 64, withPad: "0", startingAt: 0)
            return self.replacingOccurrences(of: "{id}", with: hex)
        } else {
            return self
        }
    }
}
