// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//TODO reduce direct access to contractsToFileNames etc except for absolute simple reads
struct TokenScriptFileIndices: Codable {
    typealias FileContentsHash = Int
    typealias FileName = String

    struct Entity: Codable {
        let name: String
        let fileName: FileName
    }

    var fileHashes = [FileName: FileContentsHash]()
    var signatureVerificationTypes = [FileContentsHash: TokenScriptSignatureVerificationType]()
    var contractsToFileNames = [AlphaWallet.Address: [FileName]]()
    var contractsToEntities = [FileName: [Entity]]()
    var badTokenScriptFileNames = [FileName]()
    var contractsToOldTokenScriptFileNames = [AlphaWallet.Address: [FileName]]()

    var conflictingTokenScriptFileNames: [FileName] {
        var result = [FileName]()
        for (contract, fileNames) in contractsToFileNames {
            if nonConflictingFileName(forContract: contract) == nil {
                result.append(contentsOf: fileNames)
            }
        }
        return Array(Set(result))
    }

    mutating func trackHash(forFile fileName: FileName, contents: String) {
        fileHashes[fileName] = hash(contents: contents)
    }

    mutating func removeHash(forFile fileName: FileName) {
        fileHashes.removeValue(forKey: fileName)
    }

    mutating func removeOldTokenScriptFileName(_ fileName: FileName) {
        //To be safe, we keep a copy of the keys of the dictionary (i.e. the contracts) to avoid modifying the dictionary while iterating through it
        let contracts = Array(contractsToOldTokenScriptFileNames.keys)
        for each in contracts {
            guard let index = contractsToOldTokenScriptFileNames[each]?.firstIndex(of: fileName) else { continue }
            contractsToOldTokenScriptFileNames[each]?.remove(at: index)
        }
    }

    mutating func removeBadTokenScriptFileName(_ fileName: FileName) {
        guard let index = badTokenScriptFileNames.firstIndex(of: fileName) else { return }
        badTokenScriptFileNames.remove(at: index)
    }

    ///Return the fileName if there are no other TokenScript files for that holding contract. There can be files with the exact same contents; those are fine because a TokenScript file downloaded from the official repo can support more than one holding contract, so those 2 contracts (0x1 and 0x2) will cause 0x1.tsml and 0x2.tsml to be downloaded with the same contents. This is not considered a conflict
    func nonConflictingFileName(forContract contract: AlphaWallet.Address) -> FileName? {
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

    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        if contractsToFileNames[contract].isEmpty {
            return false
        } else {
            return nonConflictingFileName(forContract: contract) == nil
        }
    }

    func contracts(inFileName fileName: FileName) -> [AlphaWallet.Address] {
        return Array(contractsToFileNames.filter { contract, fileNames in fileNames.contains(fileName) }.keys)
    }

    func write(toUrl url: URL) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: url)
    }

    func hash(contents: String) -> FileContentsHash {
        return contents.djb2hash
    }

    static func load(fromUrl url: URL) -> TokenScriptFileIndices? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TokenScriptFileIndices.self, from: data)
    }

    mutating func copySignatureVerificationTypes(_ oldVerificationTypes: [FileContentsHash: TokenScriptSignatureVerificationType]) {
        signatureVerificationTypes = .init()
        for eachHash in fileHashes.values {
            signatureVerificationTypes[eachHash] = oldVerificationTypes[eachHash]
        }
    }
}

extension String {
    //https://useyourloaf.com/blog/swift-hashable/
    //http://www.cse.yorku.ca/~oz/hash.html
    fileprivate var djb2hash: TokenScriptFileIndices.FileContentsHash {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
    }
}
