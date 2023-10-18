// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class ConstantsCredentialsTests: XCTestCase {
    func testKeysWithEqualSign() {
        XCTAssert(Constants.Credentials.extractKeyValueCredentials("key1=value1")! == (key: "key1", value: "value1"))
        XCTAssert(Constants.Credentials.extractKeyValueCredentials("key1=value1=")! == (key: "key1", value: "value1="))
        XCTAssert(Constants.Credentials.extractKeyValueCredentials("key1==value1=")! == (key: "key1", value: "=value1="))
        XCTAssert(Constants.Credentials.extractKeyValueCredentials("key1=value1=value2")! == (key: "key1", value: "value1=value2"))
        XCTAssert(Constants.Credentials.extractKeyValueCredentials("key1=value1-value2=")! == (key: "key1", value: "value1-value2="))
    }
}
