// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class AddressAndRPCServerTests: XCTestCase {
    func testEquality() {
        let address1 = AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840E")!
        let address2 = AlphaWallet.Address(string: "0x007bee82bdD9e866B2bD114780A47F2261C6840e")!
        let address3 = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
        XCTAssert(AddressAndRPCServer(address: address1, server: .main) == AddressAndRPCServer(address: address2, server: .main))
        XCTAssert(AddressAndRPCServer(address: address1, server: .rinkeby) != AddressAndRPCServer(address: address2, server: .main))
        XCTAssert(AddressAndRPCServer(address: address1, server: .main) != AddressAndRPCServer(address: address3, server: .main))
    }
}
