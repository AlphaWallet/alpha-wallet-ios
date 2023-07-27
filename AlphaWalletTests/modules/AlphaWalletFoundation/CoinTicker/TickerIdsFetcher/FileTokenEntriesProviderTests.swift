// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
import Combine
@testable import AlphaWalletFoundation

class FileTokenEntriesProviderTests: XCTestCase {
    func testLoadLocalJsonFile() async {
        let expectation = self.expectation(description: "Wait for publisher")
        let tokenEntries = try! await FileTokenEntriesProvider().tokenEntries()
        XCTAssertFalse(tokenEntries.isEmpty)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 0.1)
    }
}