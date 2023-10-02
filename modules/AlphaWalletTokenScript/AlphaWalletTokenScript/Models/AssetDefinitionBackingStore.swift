// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation

public protocol AssetDefinitionBackingStore: AnyObject {
    var delegate: AssetDefinitionBackingStoreDelegate? { get set }
    var resolver: TokenScriptResolver? { get set }
    var badTokenScriptFileNames: [Filename] { get }
    var conflictingTokenScriptFileNames: (official: [Filename], overrides: [Filename], all: [Filename]) { get }

    //Development/debug only
    func debugGetPathToScriptUriFile(url: URL) -> URL?
    func getXml(byContract contract: AlphaWallet.Address) -> String?
    //TODO we might only call this for attestations at the moment, but will actually work for tokens too, as long as we form the URL
    func getXml(byScriptUri url: URL) -> String?
    func getXmls(bySchemaId schemaUid: Attestation.SchemaUid) -> [String]
    func storeOfficialXmlForToken(_ contract: AlphaWallet.Address, xml: String, fromUrl url: URL)
    func storeOfficialXmlForAttestation(_ attestation: Attestation, withURL url: URL, xml: String)
    func deleteXmlFileDownloadedFromOfficialRepo(forContract contract: AlphaWallet.Address)
    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date?
    func isOfficial(contract: AlphaWallet.Address) -> Bool
    func isCanonicalized(contract: AlphaWallet.Address) -> Bool
    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool
    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType?
    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String)
}

public protocol AssetDefinitionBackingStoreDelegate: AnyObject {
    func tokenScriptChanged(forContractAndServer contractAndServer: AddressAndOptionalRPCServer)
    func tokenScriptChanged(forAttestationSchemaUid schemaUid: Attestation.SchemaUid)
    func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore)
}
