// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet

class AssetDefinitionDiskBackingStoreWithOverridesTests: XCTestCase {
    func testBackingStoreWithOverrides() {
        let overridesStore = AssetDefinitionInMemoryBackingStore()
        let store = AssetDefinitionDiskBackingStoreWithOverrides(overridesStore: overridesStore)
        let address = AlphaWallet.Address.make()
        XCTAssertNil(store[address])
        overridesStore[address] = "xml1"
        XCTAssertEqual(store[address], "xml1")
        overridesStore[address] = nil
        XCTAssertNil(store[address])
    }
}
