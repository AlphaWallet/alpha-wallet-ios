//
// Created by James Sangalli on 8/3/18.
//

import Foundation
import XCTest
@testable import AlphaWallet
import BigInt
import TrustKeystore

class ClaimOrderCoordinatorTests: XCTestCase {

    var expectations = [XCTestExpectation]()

    func testClaimOrder() {
        let claimOrderCoordinator = FakeClaimOrderCoordinator()
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var indices = [UInt16]()
        indices.append(14)
        let expiry = BigUInt("0")
        let v = UInt8(27)
        let r = "0x2d8e40406bf6175036ab1e1099b48590438bf48d429a8b209120fecd07894566"
        let s = "0x59ccf58ca36f681976228309fdd9de7e30e860084d9d63014fa79d48a25bb93d"

        let order = Order(price: BigUInt(0),
                          indices: indices,
                          expiry: expiry!,
                          contractAddress: "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0t",
                          count: 1,
                          nonce: BigUInt(0),
                          tokenIds: [BigUInt](),
                          spawnable: false,
                          nativeCurrencyDrop: false
        )
        
        let signedOrder = SignedOrder(order: order, message: [UInt8](), signature: "")
        expectation.fulfill()
        wait(for: expectations, timeout: 10)
    }
    
}
