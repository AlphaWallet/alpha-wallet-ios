// Copyright © 2018 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation
import XCTest

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
