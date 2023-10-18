//
// Created by James Sangalli on 8/3/18.
//

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import BigInt

class ClaimOrderCoordinatorTests: XCTestCase {

    var expectations = [XCTestExpectation]()

    func testClaimOrder() {
        //TODO doesn't actually test anything
//        let claimOrderCoordinator = FakeClaimOrderCoordinator()
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var indices = [UInt16]()
        indices.append(14)
        let expiry = BigUInt("0")!

        let token = Token(
            contract: AlphaWallet.Address(string: "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0")!,
            server: .main,
            name: "MJ Comeback",
            symbol: "MJC",
            decimals: 0,
            value: "0",
            isCustom: true,
            isDisabled: false,
            type: .erc875
        )

        let order = Order(price: BigUInt(0),
                          indices: indices,
                          expiry: expiry,
                          contractAddress: token.contractAddress,
                          count: 1,
                          nonce: BigUInt(0),
                          tokenIds: [BigUInt](),
                          spawnable: false,
                          nativeCurrencyDrop: false
        )

        let _ = SignedOrder(order: order, message: [UInt8](), signature: "")
        expectation.fulfill()
        wait(for: expectations, timeout: 0.1)
    }
}
