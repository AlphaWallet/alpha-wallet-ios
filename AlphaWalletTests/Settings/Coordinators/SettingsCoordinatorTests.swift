// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import PromiseKit
import Combine

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
        let storage = FakeTransactionsStorage(server: .main, wallet: wallet)
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
                storage.deleteAll()
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

final class FakeMultiWalletBalanceService: WalletBalanceService {
    func walletBalance(wallet: Wallet) -> AnyPublisher<WalletBalance, Never> {
        return Just(WalletBalance(wallet: wallet, values: .init()))
            .eraseToAnyPublisher()
    }

    var walletsSummary: AnyPublisher<WalletSummary, Never> {
        Just(WalletSummary(balances: []))
            .eraseToAnyPublisher()
    }
    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel {
        return NativecryptoBalanceViewModel(server: key.server, balance: Balance(value: .zero), ticker: nil)
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        return nil
    }

    func subscribableWalletBalance(wallet: Wallet) -> Subscribable<WalletBalance> {
        return .init(nil)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel, Never> {
        let viewModel = NativecryptoBalanceViewModel(server: addressAndRPCServer.server, balance: Balance(value: .zero), ticker: nil)
        return Just(viewModel)
            .eraseToAnyPublisher()
    }

    func refreshBalance(for wallet: Wallet) -> Promise<Void> {
        return .value(())
    }

    func refreshEthBalance(for wallet: Wallet) -> Promise<Void> {
        return .value(())
    }

    var subscribableWalletsSummary: Subscribable<WalletSummary> = .init(nil)

    init(config: Config = .make(), account: Wallet = .make()) {

    }

    func start() {

    }

    func refreshBalance() -> Promise<Void> {
        return .value(())
    }

    func refreshEthBalance() -> Promise<Void> {
        return .value(())
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        return .value(())
    }
}
