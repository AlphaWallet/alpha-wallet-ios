//
//  TokenGroupIdentifier.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 24/3/22.
//

import Foundation

public struct TokenEntry: Decodable {
    let contracts: [Contract]
    let group: String?
}

extension TokenEntry {
    public struct Contract: Codable, Hashable {
        let address: String
        let chainId: Int

        var key: String {
            return TokenGroupIdentifier.functional.encodePrimaryKeyWith(addressString: address, chainID: chainId)
        }
    }
}

extension TokenEntry.Contract: Equatable {
    public static func == (lhs: TokenEntry.Contract, rhs: TokenEntry.Contract) -> Bool {
        return lhs.key == rhs.key
    }
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

    public init?(tokenJsonUrl: URL) {
        do {
            try readAndDecodeData(tokenJsonUrl: tokenJsonUrl)
        } catch {
            return nil
        }
    }

    private func readAndDecodeData(tokenJsonUrl: URL) throws {
        let jsonData = try Data(contentsOf: tokenJsonUrl)
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
                returnedDictionary[key] = group
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
        return TokenGroupIdentifier.functional.encodePrimaryKeyWith(walletAddress: contractAddress, server: server)
    }
    public var isCollectibles: Bool {
        return self.type == .erc721 || self.type == .erc1155
    }
}

extension TokenViewModel: TokenGroupIdentifiable {
    public var tokenGroupKey: String {
        return TokenGroupIdentifier.functional.encodePrimaryKeyWith(walletAddress: contractAddress, server: server)
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
    case spam
}

public protocol TokenGroupIdentifiable {
    var isCollectibles: Bool { get }
    var tokenGroupKey: String { get }
}

public protocol TokenGroupIdentifierProtocol {
    static func identifier(tokenJsonUrl: URL) -> TokenGroupIdentifierProtocol?
    func identify(token: TokenGroupIdentifiable) -> TokenGroup
    func hasContract(address: String, chainID: Int) -> Bool
    func isSpam(address: String, chainID: Int) -> Bool
}

public class TokenGroupIdentifier: TokenGroupIdentifierProtocol {

    private var decodedTokenEntries: TokenGroupDictionary = TokenGroupDictionary()
    private var spamTokenEntries: Set<String> = Set<String>()

    public static func identifier(tokenJsonUrl: URL) -> TokenGroupIdentifierProtocol? {
        guard let reader = TokenJsonReader(tokenJsonUrl: tokenJsonUrl) else { return nil }
        do {
            let decodedTokenEntries = try reader.tokenGroupDictionary()
            var spamTokenEntries: Set<String> = Set<String>()
            var groupEntries: TokenGroupDictionary = TokenGroupDictionary()
            decodedTokenEntries.forEach { key, value in
                if value == TokenGroup.spam {
                    spamTokenEntries.insert(key)
                } else {
                    groupEntries[key] = value
                }
            }

            let identifier = TokenGroupIdentifier(groupEntries: groupEntries, spamEntries: spamTokenEntries)
            return identifier
        } catch {
            return nil
        }
    }

    private init(groupEntries: TokenGroupDictionary, spamEntries: Set<String>) {
        self.decodedTokenEntries = groupEntries
        self.spamTokenEntries = spamEntries
    }

    public func identify(token: TokenGroupIdentifiable) -> TokenGroup {
        if token.isCollectibles {
            return .collectibles
        }
        return decodedTokenEntries[token.tokenGroupKey, default: .assets]
    }

    public func hasContract(address: String, chainID: Int) -> Bool {
        let key = TokenGroupIdentifier.functional.encodePrimaryKeyWith(addressString: address, chainID: chainID)
        return decodedTokenEntries[key] != nil
    }

    public func isSpam(address: String, chainID: Int) -> Bool {
        let key = TokenGroupIdentifier.functional.encodePrimaryKeyWith(addressString: address, chainID: chainID)
        return spamTokenEntries.contains(key)
    }
}

extension TokenGroupIdentifier {
    enum functional {}
}

extension TokenGroupIdentifier.functional {
    static func encodePrimaryKeyWith(addressString: String, chainID: Int) -> String {
        return "\(addressString)-\(chainID)".trimmed.lowercased()
    }

    static func encodePrimaryKeyWith(walletAddress: AlphaWallet.Address, server: RPCServer) -> String {
        return encodePrimaryKeyWith(addressString: walletAddress.eip55String, chainID: server.chainID)
    }
}
