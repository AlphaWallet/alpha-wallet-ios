// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
import PromiseKit
@testable import AlphaWalletFoundation

class LocalPopularTokensCollectionTests: XCTestCase {
    //Loading JSON file from resource without static type checking is too fragile. Test to check
    private let collection = LocalPopularTokensCollection()

    func testLoadLocalJsonFile() {
        let expectation = self.expectation(description: "Wait for promise")
        firstly {
            collection.fetchTokens(for: [.main])
        }.done { results in
            XCTAssertFalse(results.isEmpty)
            expectation.fulfill()
        }.cauterize()

        waitForExpectations(timeout: 10)
    }
}

class ContractToImportFileStorageTests: XCTestCase {

    func testLoadLocalJsonFile() {
        let collection = ContractToImportFileStorage(server: .main)
        XCTAssertFalse(collection.contractsToDetect.isEmpty)
    }
}
