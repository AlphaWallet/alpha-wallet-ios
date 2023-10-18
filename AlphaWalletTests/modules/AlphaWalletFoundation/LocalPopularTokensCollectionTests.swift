// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
import Combine
@testable import AlphaWalletFoundation

class LocalPopularTokensCollectionTests: XCTestCase {
    //Loading JSON file from resource without static type checking is too fragile. Test to check
    private let collection = PopularTokensCollection(
        servers: .just([.main]),
        tokensUrl: PopularTokensCollection.bundleLocatedTokensUrl)

    private var cancellable: AnyCancellable?

    func testLoadLocalJsonFile() {
        let expectation = self.expectation(description: "Wait for promise")

        cancellable = collection.fetchTokens()
            .sink { _ in
                expectation.fulfill()
            } receiveValue: { results in
                XCTAssertFalse(results.isEmpty)
            }

        waitForExpectations(timeout: 3)
    }
}

class ContractToImportFileStorageTests: XCTestCase {

    func testLoadLocalJsonFile() {
        let collection = ContractToImportFileStorage(server: .main)
        XCTAssertFalse(collection.contractsToDetect.isEmpty)
    }
}
