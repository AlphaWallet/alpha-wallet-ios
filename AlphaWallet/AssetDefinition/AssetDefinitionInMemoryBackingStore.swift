// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionInMemoryBackingStore: AssetDefinitionBackingStore {
    private var xmls = [String: String]()

    subscript(contract: String) -> String? {
        get {
            return xmls[contract]
        }
        set(xml) {
            guard let xml = xml else { return }
            //TODO validate XML signature first
            xmls[contract] = xml
        }
    }

    func lastModifiedDataOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        return nil
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        xmls.forEach { contract, _ in
            body(contract)
        }
    }
}
