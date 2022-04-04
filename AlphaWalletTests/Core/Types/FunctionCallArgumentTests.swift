//
//  FunctionCallArgumentTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 04.04.2022.
//

import XCTest
@testable import AlphaWallet
import EthereumAddress
import BigInt

class FunctionCallArgumentTests: XCTestCase {

    func testTupleValue() throws {
        let data = [
            EthereumAddress(Constants.nativeCryptoAddressInDatabase.eip55String, type: .normal) as AnyObject,
            EthereumAddress(Constants.nativeCryptoAddressInDatabase.eip55String, type: .normal) as AnyObject
        ] as AnyObject
        let value = FunctionCall.Argument(type: .tuple([.address, .address]), anyValue: data)
        XCTAssertEqual(value.description, "[0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000]")
    }

    func testUIntValue() throws {
        let data = BigUInt("1") as AnyObject
        let value = FunctionCall.Argument(type: .uint(bits: 256), anyValue: data)
        XCTAssertEqual(value.description, "1")
    }

    func testArrayValue() throws {
        let data = [
            BigUInt("0") as AnyObject,
            BigUInt("0") as AnyObject
        ] as AnyObject
        let value = FunctionCall.Argument(type: .dynamicArray(.uint(bits: 256)), anyValue: data)
        XCTAssertEqual(value.description, "[0, 0]")
    }
}
