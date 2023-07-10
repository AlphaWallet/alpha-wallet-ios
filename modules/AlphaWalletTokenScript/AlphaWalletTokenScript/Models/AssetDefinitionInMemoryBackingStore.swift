// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

public class AssetDefinitionInMemoryBackingStore: AssetDefinitionBackingStore {
    private var xmls = [AlphaWallet.Address: String]()

    public weak var delegate: AssetDefinitionBackingStoreDelegate?
    public var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return .init()
    }
    public var conflictingTokenScriptFileNames: (official: [TokenScriptFileIndices.FileName], overrides: [TokenScriptFileIndices.FileName], all: [TokenScriptFileIndices.FileName]) {
        return (official: [], overrides: [], all: [])
    }

    public var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] {
        return .init()
    }
    public init() { }
    public subscript(contract: AlphaWallet.Address) -> String? {
        get {
            return xmls[contract]
        }
        set(xml) {
            //TODO validate XML signature first
            xmls[contract] = xml
        }
    }

    public func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return nil
    }

    public func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        xmls.forEach { contract, _ in
            body(contract)
        }
    }

    public func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return false
    }

    public func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        return true
    }

    public func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        return false
    }

    public func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        return false
    }

    public func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return nil
    }

    public func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        //do nothing
    }

    public func deleteFileDownloadedFromOfficialRepoFor(contract: AlphaWallet.Address) {
        xmls[contract] = nil
    }
}
