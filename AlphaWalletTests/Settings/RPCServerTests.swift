// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class RPCServerTests: XCTestCase {

    func testMainNetwork() {
        let server = RPCServer(chainID: 1)

        XCTAssertEqual(.main, server)
    }

    func testKovanNetwork() {
        let server = RPCServer(chainID: 42)

        XCTAssertEqual(.kovan, server)
    }

    func testRopstenNetwork() {
        let server = RPCServer(chainID: 3)

        XCTAssertEqual(.ropsten, server)
    }

    func testInitByNameCorrect() {
        for each in RPCServer.availableServers {
            XCTAssertEqual(RPCServer(name: each.name), each)
        }
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
