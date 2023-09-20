// Copyright © 2023 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWalletCore

class StringTests: XCTestCase {
    func testPaddedForBase64Encoded() {
        XCTAssertEqual("a".paddedForBase64Encoded, "a===")
        XCTAssertEqual("ab".paddedForBase64Encoded, "ab==")
        XCTAssertEqual("abc".paddedForBase64Encoded, "abc=")
        XCTAssertEqual("abcd".paddedForBase64Encoded, "abcd")
        XCTAssertEqual("abcde".paddedForBase64Encoded, "abcde===")
        XCTAssertEqual("abcdef".paddedForBase64Encoded, "abcdef==")
        XCTAssertEqual("abcdefg".paddedForBase64Encoded, "abcdefg=")
        XCTAssertEqual("abcdefgh".paddedForBase64Encoded, "abcdefgh")
        XCTAssertEqual("abcdefghi".paddedForBase64Encoded, "abcdefghi===")
    }
}
