//
//  InitialNetworkSelectionCollectionModelTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 12/5/22.
//

import XCTest
@testable import AlphaWallet

class InitialNetworkSelectionCollectionModelTestCase: XCTestCase {

    var model: InitialNetworkSelectionCollectionModel = InitialNetworkSelectionCollectionModel(selected: [RPCServer.main, RPCServer.kovan, RPCServer.avalanche])

    override func setUpWithError() throws {
        model = InitialNetworkSelectionCollectionModel(selected: [RPCServer.main, RPCServer.kovan, RPCServer.avalanche])
    }

    func testModeFilter() {
        model.set(mode: .mainnet)
        model.filter(keyword: "Binance")
        XCTAssertTrue(model.filtered == [.binance_smart_chain], "\(model.filtered)")
        model.set(mode: .testnet)
        XCTAssertTrue(model.filtered == [.binance_smart_chain_testnet], "\(model.filtered)")
    }

    func testSelected() {
        XCTAssertTrue(model.selected == [.main, .kovan, .avalanche], "\(model.selected)")
    }

    func testAddSelected() {
        model.addSelected(server: .arbitrum)
        XCTAssertTrue(model.selected == [.main, .kovan, .avalanche, .arbitrum], "\(model.selected)")
    }

    func testRemoveSelected() {
        model.removeSelected(server: .kovan)
        XCTAssertTrue(model.selected == [.main, .avalanche], "\(model.selected)")
    }

    func testRemoveNonExisting() {
        model.removeSelected(server: .binance_smart_chain)
        XCTAssertTrue(model.selected == [.main, .kovan, .avalanche], "\(model.selected)")
    }
}
