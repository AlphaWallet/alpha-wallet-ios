// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
@testable import AlphaWalletFoundation

class RPCServerTests: XCTestCase {

    func testMainNetwork() {
        let server = RPCServer(chainID: 1)

        XCTAssertEqual(.main, server)
    }

    func testGoerliNetwork() {
        let server = RPCServer(chainID: 5)

        XCTAssertEqual(.goerli, server)
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

    func testHeuristicUsingEtherscanKeyForWrongBlockchainExplorerApi() {
        for each in RPCServer.allCases where each.etherscanApiKey == RPCServer.main.etherscanApiKey {
            if let contains = each.etherscanApiRoot?.absoluteString.contains("etherscan"), !contains {
                XCTFail("\(each) should not use the Etherscan API key as its API root is: \(String(describing: each.etherscanApiRoot?.absoluteString))")
            } else {
                //OK
            }
        }
    }
}
