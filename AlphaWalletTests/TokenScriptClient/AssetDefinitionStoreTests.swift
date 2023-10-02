// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
@testable import AlphaWalletTokenScript

class AssetDefinitionStoreTests: XCTestCase {
    func testConvertsModifiedDateToStringForHTTPHeaderIfModifiedSince() {
        let date = GeneralisedTime(string: "20230405111234+0000")!.date
        XCTAssertEqual(AssetDefinitionNetworking.GetXmlFileRequest(url: URL(string: "http://google.com")!, lastModifiedDate: nil).string(fromLastModifiedDate: date), "Wed, 05 Apr 2023 11:12:34 GMT")
    }

    func testXMLAccess() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProviderImplementation.make(servers: [.main]), features: TokenScriptFeatures(), resetFolders: false)
        let address = AlphaWallet.Address.make()

        XCTAssertNil(store.getXml(byContract: address))
        store.storeOfficialXmlForToken(address, xml: "xml1", fromUrl: URL(string: "http://google.com")!)
        XCTAssertEqual(store.getXml(byContract: address), "xml1")
    }

    func testShouldNotCallCompletionBlockWithCacheCaseIfNotAlreadyCached() {
        let contractAddress = AlphaWallet.Address.make()
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProviderImplementation.make(servers: [.main]), features: TokenScriptFeatures(), resetFolders: false)
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
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore(), networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProviderImplementation.make(servers: [.main]), features: TokenScriptFeatures(), resetFolders: false)
        store.storeOfficialXmlForToken(contractAddress, xml: "something", fromUrl: URL(string: "http://google.com")!)
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
