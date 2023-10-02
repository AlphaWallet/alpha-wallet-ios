// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation
import AlphaWalletCore

public struct TokenScriptFileIndices: Codable {
    var urlToHash: [URL: FileContentsHash] = [:]
    var hashToOverridesFilename: [FileContentsHash: Filename] = [:]
    //There could more than 1 hash (file) for each contract, but we'll always use the head
    var contractToHashes = [AlphaWallet.Address: [FileContentsHash]]()
    var schemaUidToHashes: [Attestation.SchemaUid: [FileContentsHash]] = [:]
    //Only for overridden ones
    var hashToEntitiesReferenced = [FileContentsHash: [XMLHandler.Entity]]()

    //TODO restore support bookkeeping signature of TokenScript files?
    var signatureVerificationTypes = [FileContentsHash: TokenScriptSignatureVerificationType]()
    //TODO restore support bookkeeping bad TokenScript files?
    var badTokenScriptFileNames: [Filename] = []
    //TODO restore support bookkeeping bad TokenScript files?
    var conflictingTokenScriptFileNames: [Filename] = []

    //TODO restore support bookkeeping bad TokenScript files?
    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        return false
    }

    func write(toUrl url: URL) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: url)
    }

    static func load(fromUrl url: URL) -> TokenScriptFileIndices? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TokenScriptFileIndices.self, from: data)
    }

    mutating func copySignatureVerificationTypes(_ oldVerificationTypes: [FileContentsHash: TokenScriptSignatureVerificationType]) {
        signatureVerificationTypes = .init()
        for eachHash in urlToHash.values {
            signatureVerificationTypes[eachHash] = oldVerificationTypes[eachHash]
        }
    }
}

extension TokenScriptFileIndices {
    enum functional {}
}

extension URL {
    func appendingPathComponent(_ pathComponent: Filename) -> URL {
        return appendingPathComponent(pathComponent.value)
    }
}