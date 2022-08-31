// Copyright © 2019 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class AlphaWalletAddressTests: XCTestCase {
    func testIncompleteAddressShouldBeInvalid() {
        XCTAssertNotNil(AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840E"))
        XCTAssertNil(AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840"))
    }

    func testEquality() {
        let address1 = AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840E")!
        let address2 = AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840E")!
        let address3 = AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840e")!
        let address4 = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
        XCTAssert(address1 == address2)
        XCTAssert(address1 == address3)
        XCTAssert(address1 != address4)
    }
}
