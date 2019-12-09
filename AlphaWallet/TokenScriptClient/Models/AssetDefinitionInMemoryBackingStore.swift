// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionInMemoryBackingStore: AssetDefinitionBackingStore {
    private var xmls = [AlphaWallet.Address: String]()

    weak var delegate: AssetDefinitionBackingStoreDelegate?
    var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return .init()
    }
    var conflictingTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return .init()
    }

    subscript(contract: AlphaWallet.Address) -> String? {
        get {
            return xmls[contract]
        }
        set(xml) {
            //TODO validate XML signature first
            xmls[contract] = xml
        }
    }

    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return nil
    }

    func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        xmls.forEach { contract, _ in
            body(contract)
        }
    }

    func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return false
    }

    func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        return true
    }

    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        return false
    }

    func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        return false
    }

    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return nil
    }

    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        //do nothing
    }

    func deleteFileDownloadedFromOfficialRepoFor(contract: AlphaWallet.Address) {
        xmls[contract] = nil
    }
}
