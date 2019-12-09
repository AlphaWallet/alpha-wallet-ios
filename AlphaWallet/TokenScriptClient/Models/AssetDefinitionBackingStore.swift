// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

protocol AssetDefinitionBackingStore {
    var delegate: AssetDefinitionBackingStoreDelegate? { get set }
    var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] { get }
    var conflictingTokenScriptFileNames: [TokenScriptFileIndices.FileName] { get }

    subscript(contract: AlphaWallet.Address) -> String? { get set }
    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date?
    func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void)
    func isOfficial(contract: AlphaWallet.Address) -> Bool
    func isCanonicalized(contract: AlphaWallet.Address) -> Bool
    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool
    func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool
    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType?
    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String)
    func deleteFileDownloadedFromOfficialRepoFor(contract: AlphaWallet.Address)
}

protocol AssetDefinitionBackingStoreDelegate: class {
    func invalidateAssetDefinition(forContract contract: AlphaWallet.Address)
    func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore)
}
