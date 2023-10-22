//
//  RPCServerComparableTest.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/4/23.
//

@testable import AlphaWallet
import XCTest
import AlphaWalletFoundation

final class RPCServerComparableTest: XCTestCase {

    func testRPCServerComparable() {
        let sorted: [RPCServer] = [
            .custom(CustomRPC.custom(chainId: 102)), // chainId 102
            .goerli, // chainId 5 - testnet
            .main, // chainId 1
            .arbitrumGoerli, // chainId 421613 - testnet
            .arbitrum, // chainId 42161
            .binance_smart_chain_testnet, // chainId 97 - testnet
            .binance_smart_chain, // chainId 56
            .custom(CustomRPC.custom(chainId: 101)) // chainId 101
        ].sorted()
        XCTAssertTrue(sorted[0] == .main)
        XCTAssertTrue(sorted[1] == .binance_smart_chain)
        XCTAssertTrue(sorted[2] == .arbitrum)
        XCTAssertTrue(sorted[3] == .custom(chainId: 101))
        XCTAssertTrue(sorted[4] == .custom(chainId: 102))
        XCTAssertTrue(sorted[5] == .binance_smart_chain_testnet)
        XCTAssertTrue(sorted[6] == .goerli)
        XCTAssertTrue(sorted[7] == .arbitrumGoerli)
    }

}
