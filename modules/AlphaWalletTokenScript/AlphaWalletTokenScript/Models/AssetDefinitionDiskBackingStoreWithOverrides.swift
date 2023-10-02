// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation

public class AssetDefinitionDiskBackingStoreWithOverrides {
    public static let overridesDirectoryName = "assetDefinitionsOverrides"

    private let officialStore: AssetDefinitionBackingStore
    //TODO make this be a `let`
    private var overridesStore: AssetDefinitionBackingStore
    public weak var delegate: AssetDefinitionBackingStoreDelegate?
    public weak var resolver: TokenScriptResolver? {
        didSet {
            officialStore.resolver = resolver
            overridesStore.resolver = resolver
        }
    }

    public init(overridesStore: AssetDefinitionBackingStore? = nil, resetFolders: Bool) {
        self.officialStore = AssetDefinitionDiskBackingStore(resetFolders: resetFolders)
        if let overridesStore = overridesStore {
            self.overridesStore = overridesStore
        } else {
            let store = AssetDefinitionDiskBackingStore(directoryName: AssetDefinitionDiskBackingStoreWithOverrides.overridesDirectoryName, resetFolders: resetFolders)
            self.overridesStore = store
            store.watchOverridesDirectoryContentsForChanges()
        }

        self.officialStore.delegate = self
        self.overridesStore.delegate = self
    }
}

extension AssetDefinitionDiskBackingStoreWithOverrides: AssetDefinitionBackingStore {
    public var badTokenScriptFileNames: [Filename] {
        return officialStore.badTokenScriptFileNames + overridesStore.badTokenScriptFileNames
    }

    public var conflictingTokenScriptFileNames: (official: [Filename], overrides: [Filename], all: [Filename]) {
        let official = officialStore.conflictingTokenScriptFileNames.all
        let overrides = overridesStore.conflictingTokenScriptFileNames.all
        return (official: official, overrides: overrides, all: official + overrides)
    }

    public func debugGetPathToScriptUriFile(url: URL) -> URL? {
        return officialStore.debugGetPathToScriptUriFile(url: url)
    }

    public func getXml(byContract contract: AlphaWallet.Address) -> String? {
        return overridesStore.getXml(byContract: contract) ?? officialStore.getXml(byContract: contract)
    }

    public func storeOfficialXmlForToken(_ contract: AlphaWallet.Address, xml: String, fromUrl url: URL) {
        officialStore.storeOfficialXmlForToken(contract, xml: xml, fromUrl: url)
    }

    public func isOfficial(contract: AlphaWallet.Address) -> Bool {
        if overridesStore.getXml(byContract: contract) != nil {
            return false
        }
        return officialStore.isOfficial(contract: contract)
    }

    public func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        if overridesStore.getXml(byContract: contract) != nil {
            return overridesStore.isCanonicalized(contract: contract)
        } else {
            return officialStore.isCanonicalized(contract: contract)
        }
    }

    public func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        let official = officialStore.hasConflictingFile(forContract: contract)
        let overrides = overridesStore.hasConflictingFile(forContract: contract)
        if overrides {
            return true
        } else {
            return official
        }
    }

    public func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        //Even with an override, we just want to fetch the latest official version. Doesn't imply we'll use the official version
        return officialStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    public func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return overridesStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString) ?? officialStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString)
    }

    ///The implementation assumes that we never verifies the signature files in the official store when there's an override available
    public func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        if let xml = overridesStore.getXml(byContract: contract), xml == xmlString {
            overridesStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
            return
        }
        if let xml = officialStore.getXml(byContract: contract), xml == xmlString {
            officialStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
            return
        }
    }

    public func deleteXmlFileDownloadedFromOfficialRepo(forContract contract: AlphaWallet.Address) {
        officialStore.deleteXmlFileDownloadedFromOfficialRepo(forContract: contract)
    }

    public func storeOfficialXmlForAttestation(_ attestation: Attestation, withURL url: URL, xml: String) {
        officialStore.storeOfficialXmlForAttestation(attestation, withURL: url, xml: xml)
    }

    public func getXml(byScriptUri url: URL) -> String? {
        return officialStore.getXml(byScriptUri: url)
    }

    public func getXmls(bySchemaId schemaUid: Attestation.SchemaUid) -> [String] {
        return overridesStore.getXmls(bySchemaId: schemaUid) + officialStore.getXmls(bySchemaId: schemaUid)
    }
}

extension AssetDefinitionDiskBackingStoreWithOverrides: AssetDefinitionBackingStoreDelegate {
    public func tokenScriptChanged(forContractAndServer contractAndServer: AddressAndOptionalRPCServer) {
        delegate?.tokenScriptChanged(forContractAndServer: contractAndServer)
    }

    public func tokenScriptChanged(forAttestationSchemaUid schemaUid: Attestation.SchemaUid) {
        delegate?.tokenScriptChanged(forAttestationSchemaUid: schemaUid)
    }

    public func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        delegate?.badTokenScriptFilesChanged(in: self)
    }
}
