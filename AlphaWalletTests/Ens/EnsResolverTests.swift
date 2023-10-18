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

    func testResolution() async {
        let ensName = "b00n.thisisme.eth"
        let address = try? await resolver.getENSAddressFromResolver(for: ensName)
        XCTAssertEqual(address?.sameContract(as: "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362"), true, "ENS name did not resolve correctly")
    }

    func testEnsIp10WildcardAndEip3668CcipRead() async {
        let ensName = "1.offchainexample.eth"
        let address = try? await resolver.getENSAddressFromResolver(for: ensName)
        XCTAssertEqual(address?.sameContract(as: "41563129cdbbd0c5d3e1c86cf9563926b243834d"), true, "ENS name did not resolve correctly")
    }
}
