//
//  InitialNetworkSelectionCollectionModelTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 12/5/22.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class InitialNetworkSelectionCollectionModelTestCase: XCTestCase {

    var model: InitialNetworkSelectionCollectionModel = InitialNetworkSelectionCollectionModel()

    override func setUpWithError() throws {
        model = InitialNetworkSelectionCollectionModel()
        model.set(mode: .mainnet)
        model.removeAllServers()
        model.addSelected(servers: [RPCServer.main, RPCServer.kovan, RPCServer.avalanche])
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

    func testRefillSelectedWhenEmptyForMainnet() {
        model.set(mode: .mainnet)
        model.removeAllServers()
        XCTAssertTrue(model.selected.isEmpty)
        model.set(mode: .testnet)
        model.set(mode: .mainnet)
        XCTAssertFalse(model.selected.isEmpty)
        XCTAssertTrue(model.selected == InitialNetworkSelectionCollectionModel.defaultMainnetServers)
    }

    func testRefillSelectedWhenEmptyForTestnet() {
        model.set(mode: .testnet)
        model.removeAllServers()
        XCTAssertTrue(model.selected.isEmpty)
        model.set(mode: .mainnet)
        model.set(mode: .testnet)
        XCTAssertFalse(model.selected.isEmpty)
        XCTAssertTrue(model.selected == InitialNetworkSelectionCollectionModel.defaultTestnetServers)
    }
}

fileprivate extension InitialNetworkSelectionCollectionModel {
    mutating func addSelected(servers: [RPCServer]) {
        servers.forEach { addSelected(server: $0) }
    }
    mutating func removeAllServers() {
        selected.forEach { removeSelected(server: $0) }
    }
}
