// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
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

    func testOnDeleteCleanStorage() async {
        let wallet: Wallet = .make()
        let storage = FakeTransactionsStorage(wallet: wallet)
        let walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
        let keystore = FakeEtherKeystore(walletAddressesStore: walletAddressesStore)
        await storage.add(transactions: [.make()])

        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(1, transactionCount)

        var deletedWallet: Wallet?
        let expectation = self.expectation(description: "didRemoveWalletPublisher")

        removeWalletCancelable = keystore
            .didRemoveWallet
            .receive(on: RunLoop.main)
            .sink { value in
                deletedWallet = value
                expectation.fulfill()
                Task { [deletedWallet] in
                    await storage.deleteAllForTestsOnly().value

                    //let transactionCount2 = await storage.transactionCount(forServer: .main)
                    XCTAssertNotNil(deletedWallet)
                    XCTAssertTrue(wallet.address == deletedWallet!.address)
                    XCTAssertEqual(0, keystore.wallets.count)
                    //TODO test this too
                    //XCTAssertEqual(0, transactionCount2)
                }
            }

        keystore.delete(wallet: wallet)

        await fulfillment(of: [expectation], timeout: 3)
    }

    func testDeleteWallet() {
        let walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
        let keystore = FakeEtherKeystore(walletAddressesStore: walletAddressesStore)

        var wallet: Wallet?
        var deletedWallet: Wallet?
        let expectation = self.expectation(description: "didRemoveWalletPublisher")

        keystore.createHDWallet()
            .sinkAsync(receiveValue: { _wallet in
                wallet = _wallet
                keystore.delete(wallet: _wallet)
            })

        removeWalletCancelable = keystore
            .didRemoveWallet
            .receive(on: RunLoop.main)
            .sink { value in
                deletedWallet = value
                XCTAssertNotNil(deletedWallet)
                XCTAssertTrue(wallet?.address == deletedWallet?.address)
                XCTAssertEqual(0, walletAddressesStore.wallets.count)

                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 3)
    }

    func testAddDeleteWallet() {
        let walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
        let keystore = FakeEtherKeystore(walletAddressesStore: walletAddressesStore)
        let expectation = self.expectation(description: "didAddWalletPublisher")

        addWalletCancelable = keystore
            .didAddWallet
            .receive(on: RunLoop.main)
            .sink { _ in
                XCTAssertEqual(1, keystore.wallets.count)

                expectation.fulfill()
            }

        keystore.createHDWallet().sinkAsync()

        wait(for: [expectation], timeout: 20)
    }
}
