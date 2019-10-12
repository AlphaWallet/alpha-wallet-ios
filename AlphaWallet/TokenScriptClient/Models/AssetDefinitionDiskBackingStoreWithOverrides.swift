// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionDiskBackingStoreWithOverrides: AssetDefinitionBackingStore {
    private let officialStore = AssetDefinitionDiskBackingStore()
    //TODO make this be a `let`
    private var overridesStore: AssetDefinitionBackingStore
    weak var delegate: AssetDefinitionBackingStoreDelegate?
    static let overridesDirectoryName = "assetDefinitionsOverrides"

    var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return officialStore.badTokenScriptFileNames + overridesStore.badTokenScriptFileNames
    }

    var conflictingTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return officialStore.conflictingTokenScriptFileNames + overridesStore.conflictingTokenScriptFileNames
    }


    init(overridesStore: AssetDefinitionBackingStore? = nil) {
        if let overridesStore = overridesStore {
            self.overridesStore = overridesStore
        } else {
            let store = AssetDefinitionDiskBackingStore(directoryName: AssetDefinitionDiskBackingStoreWithOverrides.overridesDirectoryName)
            self.overridesStore = store
            store.watchDirectoryContents { [weak self] contract in
                self?.delegate?.invalidateAssetDefinition(forContract: contract)
            }
        }

        self.officialStore.delegate = self
        self.overridesStore.delegate = self
    }

    subscript(contract: AlphaWallet.Address) -> String? {
        get {
            return overridesStore[contract] ?? officialStore[contract]
        }
        set(xml) {
            officialStore[contract] = xml
        }
    }

    func isOfficial(contract: AlphaWallet.Address) -> Bool {
        if overridesStore[contract] != nil {
            return false
        }
        return officialStore.isOfficial(contract: contract)
    }

    func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        if overridesStore[contract] != nil {
            return overridesStore.isCanonicalized(contract: contract)
        } else {
            return officialStore.isCanonicalized(contract: contract)
        }
    }

    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        let official = officialStore.hasConflictingFile(forContract: contract)
        let overrides = overridesStore.hasConflictingFile(forContract: contract)
        if overrides {
            return true
        } else {
            return official
        }
    }

    func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        if overridesStore[contract] != nil {
            return overridesStore.hasOutdatedTokenScript(forContract: contract)
        } else {
            return officialStore.hasOutdatedTokenScript(forContract: contract)
        }
    }

    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        //Even with an override, we just want to fetch the latest official version. Doesn't imply we'll use the official version
        return officialStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        var overriddenContracts = [AlphaWallet.Address]()
        overridesStore.forEachContractWithXML { contract in
            overriddenContracts.append(contract)
            body(contract)
        }
        officialStore.forEachContractWithXML { contract in
            if !overriddenContracts.contains(contract) {
                body(contract)
            }
        }
    }

    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return overridesStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString) ?? officialStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString)
    }

    ///The implementation assumes that we never verifies the signature files in the official store when there's an override available
    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        if let xml = overridesStore[contract], xml == xmlString {
            overridesStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
            return
        }
        if let xml = officialStore[contract], xml == xmlString {
            officialStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
            return
        }
    }
}

extension AssetDefinitionDiskBackingStoreWithOverrides: AssetDefinitionBackingStoreDelegate {
    func invalidateAssetDefinition(forContract contract: AlphaWallet.Address) {
        //do nothing
    }

    func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        delegate?.badTokenScriptFilesChanged(in: self)
    }
}
