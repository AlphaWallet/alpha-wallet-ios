// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import PromiseKit
import Combine
import AlphaWalletFoundation

extension ServerDictionary {
    static func make(server: RPCServer = .main) -> ServerDictionary<WalletSession> {
        var sessons: ServerDictionary<WalletSession> = .init()
        sessons[.main] = WalletSession.make()
        return sessons
    }
}

class SettingsCoordinatorTests: XCTestCase {
    private var removeWalletCancelable: AnyCancellable?
    private var addWalletCancelable: AnyCancellable?

    func testOnDeleteCleanStorage() {
        let wallet: Wallet = .make()
        let storage = FakeTransactionsStorage(wallet: wallet)
        var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
        storage.add(transactions: [.make()])

        XCTAssertEqual(1, storage.transactionCount(forServer: .main))

        var deletedWallet: Wallet?
        let expectation = self.expectation(description: "didRemoveWalletPublisher")

        removeWalletCancelable = walletAddressesStore
            .didRemoveWalletPublisher
            .receive(on: RunLoop.main)
            .sink { value in
                deletedWallet = value
                expectation.fulfill()
                storage.deleteAllForTestsOnly()
            }

        walletAddressesStore.removeAddress(wallet)

        waitForExpectations(timeout: 10)

        XCTAssertNotNil(deletedWallet)
        XCTAssertTrue(wallet.address.sameContract(as: deletedWallet!.address))
        XCTAssertEqual(0, walletAddressesStore.wallets.count)
        XCTAssertEqual(0, storage.transactionCount(forServer: .main))
    }

    func testDeleteWallet() {
        var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)

        let wallet: Wallet = .make()
        var deletedWallet: Wallet?
        let expectation = self.expectation(description: "didRemoveWalletPublisher")

        removeWalletCancelable = walletAddressesStore
            .didRemoveWalletPublisher
            .receive(on: RunLoop.main)
            .sink { value in
                deletedWallet = value
                expectation.fulfill()
            }

        walletAddressesStore.removeAddress(wallet)

        waitForExpectations(timeout: 10)

        XCTAssertNotNil(deletedWallet)
        XCTAssertTrue(wallet.address.sameContract(as: deletedWallet!.address))
        XCTAssertEqual(0, walletAddressesStore.wallets.count)
    }

    func testAddDeleteWallet() {
        var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)

        let wallet: Wallet = .make()
        var addedAddress: AlphaWallet.Address?
        let expectation = self.expectation(description: "didAddWalletPublisher")

        addWalletCancelable = walletAddressesStore
            .didAddWalletPublisher
            .receive(on: RunLoop.main)
            .sink { value in
                addedAddress = value
                expectation.fulfill()
            }

        walletAddressesStore.addToListOfWatchEthereumAddresses(wallet.address)

        waitForExpectations(timeout: 10)

        XCTAssertNotNil(addedAddress)
        XCTAssertTrue(wallet.address.sameContract(as: addedAddress!))
        XCTAssertEqual(1, walletAddressesStore.wallets.count)
    }
}
