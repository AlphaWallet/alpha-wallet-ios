//
// Created by James Sangalli on 8/3/18.
//

import Foundation
import XCTest
@testable import Trust
import BigInt

class ClaimOrderCoordinatorTests : XCTestCase {

    var expectations = [XCTestExpectation]()

    func testClaimOrder() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var indices = [UInt16]()
        indices.append(3)
        indices.append(4)
        let expiry = BigUInt(0)
        let v = UInt8(27)
        let r = "9CAF1C785074F5948310CD1AA44CE2EFDA0AB19C308307610D7BA2C74604AE98"
        let s = "23D8D97AB44A2389043ECB3C1FB29C40EC702282DB6EE1D2B2204F8954E4B451"
        ClaimOrderCoordinator.init(web3: Web3Swift()).claimOrder(indices: indices,
                expiry: expiry, v: v, r: r, s: s) {
            result in
            print(result)
            expectation.fulfill()
        }

        wait(for: expectations, timeout: 300)
    }

}