// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

//TODO reduce direct access to contractsToFileNames etc except for absolute simple reads
public struct TokenScriptFileIndices: Codable {
    public typealias FileContentsHash = Int
    public typealias FileName = String

    public struct Entity: Codable {
        let name: String
        let fileName: FileName
    }

    public var fileHashes = [FileName: FileContentsHash]()
    public var signatureVerificationTypes = [FileContentsHash: TokenScriptSignatureVerificationType]()
    public var contractsToFileNames = [AlphaWallet.Address: [FileName]]()
    public var contractsToEntities = [FileName: [Entity]]()
    public var badTokenScriptFileNames = [FileName]()
    public var contractsToOldTokenScriptFileNames = [AlphaWallet.Address: [FileName]]()

    public var conflictingTokenScriptFileNames: [FileName] {
        var result = [FileName]()
        for (contract, fileNames) in contractsToFileNames where nonConflictingFileName(forContract: contract) == nil {
            result.append(contentsOf: fileNames)
        }
        return Array(Set(result))
    }

    public mutating func trackHash(forFile fileName: FileName, contents: String) {
        fileHashes[fileName] = hash(contents: contents)
    }

    public mutating func removeHash(forFile fileName: FileName) {
        fileHashes.removeValue(forKey: fileName)
    }

    public mutating func removeOldTokenScriptFileName(_ fileName: FileName) {
        //To be safe, we keep a copy of the keys of the dictionary (i.e. the contracts) to avoid modifying the dictionary while iterating through it
        let contracts = Array(contractsToOldTokenScriptFileNames.keys)
        for each in contracts {
            guard let index = contractsToOldTokenScriptFileNames[each]?.firstIndex(of: fileName) else { continue }
            contractsToOldTokenScriptFileNames[each]?.remove(at: index)
        }
    }

    public mutating func removeBadTokenScriptFileName(_ fileName: FileName) {
        guard let index = badTokenScriptFileNames.firstIndex(of: fileName) else { return }
        badTokenScriptFileNames.remove(at: index)
    }

    ///Return the fileName if there are no other TokenScript files for that holding contract. There can be files with the exact same contents; those are fine because a TokenScript file downloaded from the official repo can support more than one holding contract, so those 2 contracts (0x1 and 0x2) will cause 0x1.tsml and 0x2.tsml to be downloaded with the same contents. This is not considered a conflict
    public func nonConflictingFileName(forContract contract: AlphaWallet.Address) -> FileName? {
        guard let fileNames = contractsToFileNames[contract] else { return nil }
        let uniqueHashes = Set(fileNames.map {
            fileHashes[$0]
        })
        if uniqueHashes.count == 1 {
            return fileNames.first
        } else {
            return nil
        }
    }

    public func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        if contractsToFileNames[contract].isEmpty {
            return false
        } else {
            return nonConflictingFileName(forContract: contract) == nil
        }
    }

    public func contracts(inFileName fileName: FileName) -> [AlphaWallet.Address] {
        return Array(contractsToFileNames.filter { _, fileNames in fileNames.contains(fileName) }.keys)
    }

    public func write(toUrl url: URL) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: url)
    }

    public func hash(contents: String) -> FileContentsHash {
        //The value returned by `hashValue` might be subject to change and 2 strings that has the same `hasValue` *might* not be identical, but should be good enough for now. It is much faster than other commonly available hashes and we need it to be very fast because it is called once for each file upon startup
        return contents.hashValue
    }

    public static func load(fromUrl url: URL) -> TokenScriptFileIndices? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TokenScriptFileIndices.self, from: data)
    }

    public mutating func copySignatureVerificationTypes(_ oldVerificationTypes: [FileContentsHash: TokenScriptSignatureVerificationType]) {
        signatureVerificationTypes = .init()
        for eachHash in fileHashes.values {
            signatureVerificationTypes[eachHash] = oldVerificationTypes[eachHash]
        }
    }
}
