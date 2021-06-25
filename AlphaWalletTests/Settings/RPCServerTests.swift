// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

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
        for each in RPCServer.allCases {
            XCTAssertEqual(RPCServer(name: each.name), each)
        }
    }

    func testInitByChainIdCorrect() {
        for each in RPCServer.allCases {
            XCTAssertEqual(RPCServer(chainID: each.chainID), each)
        }
    }
}
