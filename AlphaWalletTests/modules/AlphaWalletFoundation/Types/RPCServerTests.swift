// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
@testable import AlphaWalletFoundation
import XCTest

class RPCServerTests: XCTestCase {
    func testMainNetwork() {
        let server = RPCServer(chainID: 1)

        XCTAssertEqual(.main, server)
    }

    func testSepoliaNetwork() {
        let server = RPCServer(chainID: 11155111)

        XCTAssertEqual(.sepolia, server)
    }

    func testInitByChainIdCorrect() {
        for each in RPCServer.availableServers {
            XCTAssertEqual(RPCServer(chainID: each.chainID), each)
        }
    }

    func testDisplayOrderPriorityUnique() {
        let all = RPCServer.availableServers
        let orders = Set(all.map(\.displayOrderPriority))
        XCTAssertEqual(orders.count, all.count)
    }

    func testDefaultMainnetServers() {
        let all = Constants.defaultEnabledServers
        XCTAssertTrue(all.contains(.main))
    }
}
