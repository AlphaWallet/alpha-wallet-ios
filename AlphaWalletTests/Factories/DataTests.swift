//
//  DataTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 28.12.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

final class DataTests: XCTestCase {

    func testInit() throws {
        XCTAssertThrowsError(try Data(json: NSNull.init()))

        let json: [String: Any] = ["key": NSNull()]

        XCTAssertNoThrow(try Data(json: json))
        guard let string = "string".data(using: .utf8) else { return }

        XCTAssertThrowsError(try Data(json: string))
    }

}
