// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import XCTest
import Combine
import AlphaWalletFoundation
import AlphaWalletCore
import AlphaWalletWeb3

class EnsResolverTests: XCTestCase {
    func testNameHash() {
        XCTAssertEqual("".nameHash, "0x0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertEqual("eth".nameHash, "0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae")
        XCTAssertEqual("foo.eth".nameHash, "0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f")
    }
    private var cancelable = Set<AnyCancellable>()
    private lazy var resolver: EnsResolver = {
        return EnsResolver(
            storage: FakeEnsRecordsStorage(),
            blockchainProvider: RpcBlockchainProvider(server: .main, analytics: FakeAnalyticsService(), params: .defaultParams(for: .main)))
    }()
    func testResolution() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "b00n.thisisme.eth"

        resolver.getENSAddressFromResolver(for: ensName)
            .sink(receiveCompletion: { response in
                switch response {
                case .finished:
                    break
                case .failure(let error):
                    guard case .embedded(let e) = error, let pe = e as? PromiseError, let e = pe.embedded as? AlphaWalletWeb3.Web3Error else {
                        XCTFail("Unknown error: \(error)")
                        return
                    }
                    switch e {
                    case .rateLimited:
                        break
                    default:
                        XCTFail("Unknown error: \(error)")
                    }
                }
                expectation.fulfill()
            }, receiveValue: { address in
                XCTAssertTrue(address.sameContract(as: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362"), "ENS name did not resolve correctly")
            }).store(in: &cancelable)

        wait(for: expectations, timeout: 20)
    }

    func testResolutionThatHasDifferentOwnerAndResolver() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "ethereum.eth"
        resolver.getENSAddressFromResolver(for: ensName)
            .sink(receiveCompletion: { response in
                switch response {
                case .finished:
                    break
                case .failure(let error):
                    guard case .embedded(let e) = error, let pe = e as? PromiseError, let e = pe.embedded as? AlphaWalletWeb3.Web3Error else {
                        XCTFail("Unknown error: \(error)")
                        return
                    }
                    switch e {
                    case .rateLimited:
                        break
                    default:
                        XCTFail("Unknown error: \(error)")
                    }
                }
                expectation.fulfill()
            }, receiveValue: { address in
                XCTAssertTrue(address.sameContract(as: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"), "ENS name did not resolve correctly")
            }).store(in: &cancelable)

        wait(for: expectations, timeout: 20)
    }

    func testEnsIp10WildcardAndEip3668CcipRead() {
        var expectations = [XCTestExpectation]()
        let expectation = self.expectation(description: "Wait for ENS name to be resolved")
        expectations.append(expectation)
        let ensName = "1.offchainexample.eth"
        resolver.getENSAddressFromResolver(for: ensName)
            .sink(receiveCompletion: { response in
                switch response {
                case .finished:
                    break
                case .failure(let error):
                    guard case .embedded(let e) = error, let pe = e as? PromiseError, let e = pe.embedded as? AlphaWalletWeb3.Web3Error else {
                        XCTFail("Unknown error: \(error)")
                        return
                    }
                    switch e {
                    case .rateLimited:
                        break
                    default:
                        XCTFail("Unknown error: \(error)")
                    }
                }
                expectation.fulfill()
            }, receiveValue: { address in
                XCTAssertTrue(address.sameContract(as: "41563129cdbbd0c5d3e1c86cf9563926b243834d"), "ENS name did not resolve correctly")
            }).store(in: &cancelable)

        wait(for: expectations, timeout: 100)
    }

    private func makeServerForMainnet() -> RPCServer {
        return .main
    }
}
