// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import Foundation

class TokensDataStoreTest: XCTestCase {
    private let storage = FakeTokensDataStore()
    private let token = TokenObject(
            contract: "0x001",
            value: "0"
    )

    override func setUp() {
        storage.add(tokens: [token])
    }

    //We make a call to update token in datastore to store the updated balance after an async call to fetch the balance over the web. Token in the datastore might have been deleted when the web call is completed. Make sure this doesn't crash
    func testUpdateDeletedTokensDoNotCrash() {
        storage.delete(tokens: [token])
        XCTAssertNoThrow(storage.update(token: token, action: .value(1)))
    }
}
