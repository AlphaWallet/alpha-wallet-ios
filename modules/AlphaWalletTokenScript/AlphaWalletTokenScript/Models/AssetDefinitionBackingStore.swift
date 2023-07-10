// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

public protocol AssetDefinitionBackingStore: AnyObject {
    var delegate: AssetDefinitionBackingStoreDelegate? { get set }
    var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] { get }
    var conflictingTokenScriptFileNames: (official: [TokenScriptFileIndices.FileName], overrides: [TokenScriptFileIndices.FileName], all: [TokenScriptFileIndices.FileName]) { get }
    var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] { get }

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

public protocol AssetDefinitionBackingStoreDelegate: AnyObject {
    func invalidateAssetDefinition(forContractAndServer contractAndServer: AddressAndOptionalRPCServer)
    func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore)
}
