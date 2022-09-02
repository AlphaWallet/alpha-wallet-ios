//
//  ValidatorsTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 20.01.2022.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class ValidatorsTests: XCTestCase {

    func testEthereumAddressValidator() throws {
        let e1 = EthereumAddressValidator(msg: "").isValid(value: "0x007bee82bdD9e866B2bD114780A47F2261C6840")
        XCTAssertNotNil(e1)

        let e2 = EthereumAddressValidator(msg: "").isValid(value: "0x007bee82bdD9e866B2bD114780A47F2261C6840E")
        XCTAssertNil(e2)
    }

    func testPrivateKeyValidator() throws {
        let e1 = PrivateKeyValidator(msg: "").isValid(value: "0x007bee82bdD9e866B2bD1")
        XCTAssertNotNil(e1)

        let e2 = PrivateKeyValidator(msg: "").isValid(value: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")
        XCTAssertNil(e2)
    }

    func testMnemonicLengthValidator() throws {
        let e1 = MnemonicLengthValidator(message: "").isValid(value: "nuclear you cage screen tribe trick limb smart dad voice nut jealous")
        XCTAssertNil(e1)

        let e2 = MnemonicLengthValidator(message: "").isValid(value: "nuclear you cage screen One of the two will be used Which one is undefined")
        XCTAssertNotNil(e2)
    }

    func testMnemonicInWordListValidator() throws {
        let e1 = MnemonicInWordListValidator(msg: "").isValid(value: "nuclear you cage screen")
        XCTAssertNil(e1)

        let e2 = MnemonicLengthValidator(message: "").isValid(value: "hello")
        XCTAssertNotNil(e2)
    }

}
