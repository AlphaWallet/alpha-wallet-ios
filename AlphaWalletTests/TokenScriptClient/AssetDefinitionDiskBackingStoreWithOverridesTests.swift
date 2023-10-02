// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletAddress
import AlphaWalletTokenScript

class AssetDefinitionDiskBackingStoreWithOverridesTests: XCTestCase {
    func testBackingStoreWithOverrides() {
        let overridesStore = AssetDefinitionInMemoryBackingStore()
        let store = AssetDefinitionDiskBackingStoreWithOverrides(overridesStore: overridesStore, resetFolders: false)
        let address = AlphaWallet.Address.make()
        XCTAssertNil(store.getXml(byContract: address))
        overridesStore.storeOfficialXmlForToken(address, xml: "xml1", fromUrl: URL(string: "http://google.com")!)
        XCTAssertEqual(store.getXml(byContract: address), "xml1")
        overridesStore.deleteXmlFileDownloadedFromOfficialRepo(forContract: address)
        XCTAssertNil(store.getXml(byContract: address))
    }
}
