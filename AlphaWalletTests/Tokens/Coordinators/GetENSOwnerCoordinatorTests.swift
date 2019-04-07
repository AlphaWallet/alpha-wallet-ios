// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import XCTest

class GetENSOwnerCoordinatorTests: XCTestCase {
    func testNameHash() {
        XCTAssertEqual("".nameHash, "0x0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertEqual("eth".nameHash, "0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae")
        XCTAssertEqual("foo.eth".nameHash, "0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f")
    }

    func testResolution() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "b00n.thisisme.eth"
        let server = makeServerForMainnet()
        GetENSOwnerCoordinator(server: server).getENSOwner(for: ensName) { result in
            if let address = result.value, address.address.sameContract(as: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362") {
                expectation.fulfill()
            }
        }
        wait(for: expectations, timeout: 10)
    }

    private func makeServerForMainnet() -> RPCServer {
        return .main
    }
}
