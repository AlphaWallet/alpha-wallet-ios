// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
import PromiseKit
@testable import AlphaWalletFoundation

class LocalPopularTokensCollectionTests: XCTestCase {
    //Loading JSON file from resource without static type checking is too fragile. Test to check
    func testLoadLocalJsonFile() {
        let expectation = self.expectation(description: "Wait for promise")
        firstly {
            LocalPopularTokensCollection().fetchTokens(for: [.main])
        }.done { results in
            XCTAssertFalse(results.isEmpty)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.1)
    }
}