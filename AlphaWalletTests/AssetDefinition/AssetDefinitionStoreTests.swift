// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import Trust

class AssetDefinitionStoreTests: XCTestCase {
    func testConvertsModifiedDateToStringForHTTPHeaderIfModifiedSince() {
        let date = GeneralisedTime(string: "20230405111234+0000")!.date
        XCTAssertEqual(AssetDefinitionStore().string(fromLastModifiedDate: date), "Wed, 05 Apr 2023 11:12:34 GMT")
    }

    func testXMLAccess() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        XCTAssertNil(store["0x1"])
        store["0x1"] = "xml1"
        XCTAssertEqual(store["0x1"], "xml1")
    }
}
