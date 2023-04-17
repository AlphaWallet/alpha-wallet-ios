//
//  HostBasedTokenUriMapperTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 17.03.2023.
//

import XCTest
@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

class HostBasedTokenUriMapperTests: XCTestCase {

    func testHideContractTwiceDoesNotCrash() {
        let x = HostBasedTokenUriMapper(host: "api.mintkudos.xyz")
        let u = URL(string: "https://api.mintkudos.xyz/metadata/3ba0000000000000000000000000000000000000000000000000000000000000")!
        let r = x.map(uri: u)

        XCTAssertNotNil(r)
        XCTAssertEqual(r!.absoluteString, "https://api.mintkudos.xyz/metadata/954")
    }
}

