// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import XCTest
import PromiseKit

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
        firstly {
            GetENSAddressCoordinator(server: server).getENSAddressFromResolver(forName: ensName)
        }.done { address in
            if address.sameContract(as: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362") {
                expectation.fulfill()
            } else {
                XCTFail("ENS name did not resolve correctly")
            }
        }.catch { error in
            XCTFail("ENS name did not resolve correctly: \(error)")
        }
        wait(for: expectations, timeout: 20)
    }

    func testResolutionThatHasDifferentOwnerAndResolver() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "ethereum.eth"
        let server = makeServerForMainnet()
        firstly {
            GetENSAddressCoordinator(server: server).getENSAddressFromResolver(forName: ensName)
        }.done { address in
            if address.sameContract(as: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe") {
                expectation.fulfill()
            } else {
                XCTFail("ENS name did not resolve correctly")
            }
        }.catch { _ in
            XCTFail("ENS name did not resolve correctly")
        }
        wait(for: expectations, timeout: 20)
    }

    func testEnsIp10WildcardAndEip3668CcipRead() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "1.offchainexample.eth"
        let server = makeServerForMainnet()
        firstly {
            GetENSAddressCoordinator(server: server).getENSAddressFromResolver(forName: ensName)
        }.done { address in
            if address.sameContract(as: "0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5") {
                expectation.fulfill()
            } else {
                XCTFail("ENS name relying on ENSIP-10 did not resolve correctly")
            }
        }.catch { _ in
            XCTFail("ENS name relying on ENSIP-10 did not resolve correctly")
        }
        wait(for: expectations, timeout: 20)
    }

    private func makeServerForMainnet() -> RPCServer {
        return .main
    }
}
