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

    func testShouldNotCallCompletionBlockWithCacheCaseIfNotAlreadyCached() {
        let contractAddress = "0x1"
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        let expectation = XCTestExpectation(description: "cached case should not be called")
        expectation.isInverted = true
        store.fetchXML(forContract: contractAddress, useCacheAndFetch: true) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .cached:
                expectation.fulfill()
            case .updated, .unmodified, .error:
                break
            }
        }
        wait(for: [expectation], timeout: 0)
    }

    func testShouldCallCompletionBlockWithCacheCaseIfAlreadyCached() {
        let contractAddress = "0x1"
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        store[contractAddress] = "something"
        let expectation = XCTestExpectation(description: "cached case should be called")
        store.fetchXML(forContract: contractAddress, useCacheAndFetch: true) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .cached:
                expectation.fulfill()
            case .updated, .unmodified, .error:
                break
            }
        }
        wait(for: [expectation], timeout: 0)
    }
}
