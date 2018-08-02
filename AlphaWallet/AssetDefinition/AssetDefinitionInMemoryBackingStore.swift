// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionInMemoryBackingStore: AssetDefinitionBackingStore {
    private var xmls = [String: String]()
    weak var delegate: AssetDefinitionBackingStoreDelegate?

    subscript(contract: String) -> String? {
        get {
            return xmls[contract]
        }
        set(xml) {
            //TODO validate XML signature first
            xmls[contract] = xml
        }
    }

    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        return nil
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        xmls.forEach { contract, _ in
            body(contract)
        }
    }

    func isOfficial(contract: String) -> Bool {
        return false
    }
}
