// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import XCTest
import PromiseKit

class EnsResolverTests: XCTestCase {
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
            EnsResolver(server: server, storage: FakeEnsRecordsStorage()).getENSAddressFromResolver(for: ensName)
        }.done { address in
            XCTAssertTrue(address.sameContract(as: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362"), "ENS name did not resolve correctly")
        }.ensure {
            expectation.fulfill()
        }.catch { error in
            XCTFail("Unknown error: \(error)")
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
            EnsResolver(server: server, storage: FakeEnsRecordsStorage()).getENSAddressFromResolver(for: ensName)
        }.done { address in
            XCTAssertTrue(address.sameContract(as: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"), "ENS name did not resolve correctly")
        }.ensure {
            expectation.fulfill()
        }.catch {error in
            XCTFail("Unknown error: \(error)")
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
            EnsResolver(server: server, storage: FakeEnsRecordsStorage()).getENSAddressFromResolver(for: ensName)
        }.done { address in
            XCTAssertTrue(address.sameContract(as: "41563129cdbbd0c5d3e1c86cf9563926b243834d"), "ENS name did not resolve correctly")
        }.ensure {
            expectation.fulfill()
        }.catch {error in
            XCTFail("Unknown error: \(error)")
        }
        wait(for: expectations, timeout: 20)
    }

    private func makeServerForMainnet() -> RPCServer {
        return .main
    }
}
