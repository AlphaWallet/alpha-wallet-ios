// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import Trust

class AssetDefinitionDiskBackingStoreWithOverridesTests: XCTestCase {
    func testBackingStoreWithOverrides() {
        let overridesStore = AssetDefinitionInMemoryBackingStore()
        let store = AssetDefinitionDiskBackingStoreWithOverrides(overridesStore: overridesStore)
        XCTAssertNil(store["0x1"])
        overridesStore["0x1"] = "xml1"
        XCTAssertEqual(store["0x1"], "xml1")
        overridesStore["0x1"] = nil
        XCTAssertNil(store["0x1"])
    }
}
