// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation

public class AssetDefinitionInMemoryBackingStore: AssetDefinitionBackingStore {
    private var xmls = [AlphaWallet.Address: String]()

    public weak var delegate: AssetDefinitionBackingStoreDelegate?
    public weak var resolver: TokenScriptResolver?
    public var badTokenScriptFileNames: [Filename] {
        return .init()
    }
    public var conflictingTokenScriptFileNames: (official: [Filename], overrides: [Filename], all: [Filename]) {
        return (official: [], overrides: [], all: [])
    }

    public init() { }

    public func debugGetPathToScriptUriFile(url: URL) -> URL? {
        return nil
    }

    public func getXml(byContract contract: AlphaWallet.Address) -> String? {
        return xmls[contract]
    }

    public func storeOfficialXmlForToken(_ contract: AlphaWallet.Address, xml: String, fromUrl url: URL) {
        //TODO validate XML signature first
        xmls[contract] = xml
    }

    public func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return nil
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

    public func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return nil
    }

    public func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        //do nothing
    }

    public func deleteXmlFileDownloadedFromOfficialRepo(forContract contract: AlphaWallet.Address) {
        xmls[contract] = nil
    }

    public func storeOfficialXmlForAttestation(_ attestation: Attestation, withURL url: URL, xml: String) {
    }

    public func getXml(byScriptUri url: URL) -> String? {
        return nil
    }

    public func getXmls(bySchemaId schemaUid: Attestation.SchemaUid) -> [String] {
        return []
    }
}
