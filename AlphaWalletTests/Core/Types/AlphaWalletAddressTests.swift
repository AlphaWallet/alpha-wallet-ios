// Copyright © 2019 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet

class AlphaWalletAddressTests: XCTestCase {
    func testIncompleteAddressShouldBeInvalid() {
        XCTAssertNotNil(AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840E"))
        XCTAssertNil(AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840"))
    }
}
