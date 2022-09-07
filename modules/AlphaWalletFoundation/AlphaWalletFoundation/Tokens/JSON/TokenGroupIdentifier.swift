//
//  TokenGroupIdentifier.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 24/3/22.
//

import Foundation

public struct Contract: Codable, Hashable {
    let address: String
    let chainId: Int

    var key: String {
        let returnKey = address + ":" + String(chainId)
        return returnKey.trimmed.lowercased()
    }
}

extension Contract: Equatable {
    public static func == (lhs: Contract, rhs: Contract) -> Bool {
        return lhs.key == rhs.key
    }
}

public struct TokenEntry: Decodable {
    let contracts: [Contract]
    let group: String?
}

public class TokenJsonReader {

    enum error: Error {
        case duplicateKey(String)
        case unknownTokenGroup
        case fileDoesNotExist
        case fileIsNotUtf8
        case fileCannotBeDecoded // Not Json format or Json data does not match Swift Decodable struct
        case unknown(Error)
    }

    private var decodedTokenEntries: [TokenEntry] = [TokenEntry]()

    public init?(fromLocalFileNameWithoutSuffix fileName: String) {
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

    public func tokenGroupDictionary() throws -> TokenGroupDictionary {
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

extension Token: TokenGroupIdentifiable {
    public var tokenGroupKey: String {
        let key = self.contractAddress.eip55String + ":" + String(self.server.chainID)
        return key.trimmed.lowercased()
    }
    public var isCollectibles: Bool {
        return self.type == .erc721 || self.type == .erc1155
    }
}

extension TokenViewModel: TokenGroupIdentifiable {
    public var tokenGroupKey: String {
        let key = self.contractAddress.eip55String + ":" + String(self.server.chainID)
        return key.trimmed.lowercased()
    }

    public var isCollectibles: Bool {
        return self.type == .erc721 || self.type == .erc1155
    }
}

public typealias TokenGroupDictionary = [String: TokenGroup]

public enum TokenGroup: String {
    case assets
    case defi
    case governance
    case collectibles
}

public protocol TokenGroupIdentifiable {
    var isCollectibles: Bool { get }
    var tokenGroupKey: String { get }
}

public protocol TokenGroupIdentifierProtocol {
    static func identifier(fromFileName: String) -> TokenGroupIdentifierProtocol?
    func identify(token: TokenGroupIdentifiable) -> TokenGroup
}

public class TokenGroupIdentifier: TokenGroupIdentifierProtocol {

    private var decodedTokenEntries: TokenGroupDictionary = TokenGroupDictionary()

    public static func identifier(fromFileName fileName: String) -> TokenGroupIdentifierProtocol? {
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

    public func identify(token: TokenGroupIdentifiable) -> TokenGroup {
        if token.isCollectibles {
            return .collectibles
        }
        return decodedTokenEntries[token.tokenGroupKey] ?? .assets
    }

}

public protocol TokenGroupIdentifieble {
    var isCollectibles: Bool { get }
    var tokenGroupKey: String { get }
}
