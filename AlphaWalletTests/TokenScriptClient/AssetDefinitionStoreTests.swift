// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class AssetDefinitionStoreTests: XCTestCase {
    func testConvertsModifiedDateToStringForHTTPHeaderIfModifiedSince() {
        let date = GeneralisedTime(string: "20230405111234+0000")!.date
        XCTAssertEqual(AssetDefinitionNetworking.GetXmlFileRequest(url: URL(string: "http://google.com")!, lastModifiedDate: nil).string(fromLastModifiedDate: date), "Wed, 05 Apr 2023 11:12:34 GMT")
    }

    func testXMLAccess() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), sessionsProvider: .make())
        let address = AlphaWallet.Address.make()
        XCTAssertNil(store[address])
        store[address] = "xml1"
        XCTAssertEqual(store[address], "xml1")
    }

    func testShouldNotCallCompletionBlockWithCacheCaseIfNotAlreadyCached() {
        let contractAddress = AlphaWallet.Address.make()
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), sessionsProvider: .make())
        let expectation = XCTestExpectation(description: "cached case should not be called")
        expectation.isInverted = true
        store.fetchXML(forContract: contractAddress, server: nil, useCacheAndFetch: true) { [weak self] result in
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
        let contractAddress = AlphaWallet.Address.ethereumAddress(eip55String: "0x0000000000000000000000000000000000000001")
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), sessionsProvider: .make())
        store[contractAddress] = "something"
        let expectation = XCTestExpectation(description: "cached case should be called")
        store.fetchXML(forContract: contractAddress, server: nil, useCacheAndFetch: true) { [weak self] result in
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
