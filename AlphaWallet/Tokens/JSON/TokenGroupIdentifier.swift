//
//  TokenGroupIdentifier.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 24/3/22.
//

import Foundation

fileprivate struct Contract: Decodable {
    let address: String
    let chainId: Int
    var key: String {
        let returnKey = address + ":" + String(chainId)
        return returnKey.trimmed.lowercased()
    }
}

fileprivate struct TokenEntry: Decodable {
    let contracts: [Contract]
    let group: String?
}

fileprivate class TokenJsonReader {

    enum error: Error {
        case duplicateKey(String)
        case unknownTokenGroup
        case fileDoesNotExist
        case fileIsNotUtf8
        case fileCannotBeDecoded // Not Json format or Json data does not match Swift Decodable struct
        case unknown(Error)
    }

    private var decodedTokenEntries: [TokenEntry] = [TokenEntry]()

    init?(fromLocalFileNameWithoutSuffix fileName: String) {
        do {
            try readAndDecodeData(fileName: fileName)
        } catch {
            return nil
        }
    }

    private func readAndDecodeData(fileName: String) throws {
        guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: "json") else { throw TokenJsonReader.error.fileDoesNotExist }
        guard let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) else { throw TokenJsonReader.error.fileIsNotUtf8 }
        do {
            decodedTokenEntries = try JSONDecoder().decode([TokenEntry].self, from: jsonData)
        } catch DecodingError.dataCorrupted {
            throw TokenJsonReader.error.fileCannotBeDecoded
        } catch {
            throw TokenJsonReader.error.unknown(error)
        }
    }

    func tokenGroupDictionary() throws -> TokenGroupDictionary {
        var returnedDictionary = TokenGroupDictionary()
        for entry in decodedTokenEntries {
            guard let group = tokenGroup(fromString: entry.group) else { throw TokenJsonReader.error.unknownTokenGroup }
            guard group != .collectibles else {
                continue
            }
            for contract in entry.contracts {
                let key = contract.key
                guard returnedDictionary[key] == nil else {
                    // We ignore the current key if it's already used
                    continue
                }
                returnedDictionary[contract.key] = group
            }
        }
        return returnedDictionary
    }

    private func tokenGroup(fromString: String?) -> TokenGroup? {
        // Default is assets if no group is specified
        guard let fromString = fromString else { return .assets }
        return TokenGroup(rawValue: fromString.lowercased())
    }

}

fileprivate extension TokenObject {
    var tokenGroupKey: String {
        let key = self.contract + ":" + String(self.chainId)
        return key.trimmed.lowercased()
    }
    var isCollectibles: Bool {
        return self.type == .erc721 || self.type == .erc1155
    }
}

typealias TokenGroupDictionary = [String: TokenGroup]

enum TokenGroup: String {
    case assets
    case defi
    case governance
    case collectibles
}

protocol TokenGroupIdentifierProtocol {
    static func identifier(fromFileName: String) -> TokenGroupIdentifierProtocol?
    func identify(tokenObject: TokenObject) -> TokenGroup
}

class TokenGroupIdentifier: TokenGroupIdentifierProtocol {

    private var decodedTokenEntries: TokenGroupDictionary = TokenGroupDictionary()

    static func identifier(fromFileName fileName: String) -> TokenGroupIdentifierProtocol? {
        guard let reader = TokenJsonReader(fromLocalFileNameWithoutSuffix: fileName) else { return nil }
        do {
            let identifier = TokenGroupIdentifier(decodedTokenEntries: try reader.tokenGroupDictionary())
            return identifier
        } catch {
            return nil
        }
    }

    private init(decodedTokenEntries: TokenGroupDictionary) {
        self.decodedTokenEntries = decodedTokenEntries
    }

    func identify(tokenObject: TokenObject) -> TokenGroup {
        if tokenObject.isCollectibles {
            return .collectibles
        }
        return decodedTokenEntries[tokenObject.tokenGroupKey] ?? .assets
    }

}
