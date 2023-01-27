//
//  Erc721TokenUriMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import BigInt

class Erc721TokenUriMethodCall: ContractMethodCall {
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

class Erc721UriMethodCall: ContractMethodCall {
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
