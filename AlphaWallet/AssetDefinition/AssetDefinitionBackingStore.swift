// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

protocol AssetDefinitionBackingStore {
    subscript(contract: String) -> String? { get set }
    func lastModifiedDataOfCachedAssetDefinitionFile(forContract contract: String) -> Date?
    func forEachContractWithXML(_ body: (String) -> Void)
}

extension AssetDefinitionBackingStore {
    func standardizedName(ofContract contract: String) -> String {
        return contract.add0x.lowercased()
    }
}
