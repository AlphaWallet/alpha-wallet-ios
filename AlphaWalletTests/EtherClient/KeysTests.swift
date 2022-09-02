// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class KeysTests: XCTestCase {
    //Keys *must* be 64 characters (i.e. 32 bytes) for this test
    //Order of curve n = fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140, private keys must be smaller than n
    func testImportInvalidPrivateKeys() {
        XCTAssertNil(deriveAddressFromPrivateKey("00"))
        XCTAssertNil(deriveAddressFromPrivateKey("0xff"))
        XCTAssertNil(deriveAddressFromPrivateKey("ff"))
        XCTAssertNil(deriveAddressFromPrivateKey("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\n"))
        XCTAssertNil(deriveAddressFromPrivateKey("ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccd"))
        XCTAssertNotNil(deriveAddressFromPrivateKey("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"))
        XCTAssertNil(deriveAddressFromPrivateKey("ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"))
        XCTAssertNotNil(deriveAddressFromPrivateKey("fffffffccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"))
        XCTAssertNil(deriveAddressFromPrivateKey("fffffffcccccccccccccccccccccccccccccccccccccccccccccccccccccccck"))
        XCTAssertNil(deriveAddressFromPrivateKey("0000000000000000000000000000000000000000000000000000000000000000"))
        //key == order of curve n - 1, OK
        XCTAssertNotNil(deriveAddressFromPrivateKey("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140"))
        //key == order of curve n, invalid key
        XCTAssertNil(deriveAddressFromPrivateKey("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"))
        //key == order of curve n+1, invalid key
        XCTAssertNil(deriveAddressFromPrivateKey("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142"))
    }

    private func deriveAddressFromPrivateKey(_ privateKeyInput: String) -> AlphaWallet.Address? {
        let privateKey = Data(hexString: privateKeyInput)
        guard let privateKey = privateKey else { return nil }
        return AlphaWallet.Address(fromPrivateKey: privateKey)
    }
}
