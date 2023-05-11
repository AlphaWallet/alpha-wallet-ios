//
//  MigrateToSupportEip1559Transactions.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 10.03.2023.
//

import Foundation
import Combine
import AlphaWalletLogger

public final class MigrateToSupportEip1559Transactions: Service {
    private let serversProvider: ServersProvidable
    private let keychain: Keystore
    private var cancelable = Set<AnyCancellable>()

    public init(serversProvider: ServersProvidable,
                keychain: Keystore) {

        self.serversProvider = serversProvider
        self.keychain = keychain
    }

    public func perform() {
        keychain.walletsPublisher
            .filter { _ in !Config.hasMigratedToEip1559TransactionsSupport }
            .first()
            .handleEvents(receiveOutput: { _ in infoLog("[Eip1559] has migrated to support Eip1559") })
            .sink { [weak self, serversProvider] wallets in
                for wallet in wallets {
                    for server in serversProvider.allServers {
                        self?.resetTransactionsFetchingState(server: server, wallet: wallet)
                    }

                    let storage = TransactionDataStore(store: RealmStore.storage(for: wallet))
                    storage.deleteAll()
                }

                Config.setAsMigratedToEip1559TransactionsSupport()
            }.store(in: &cancelable)
    }

    private func resetTransactionsFetchingState(server: RPCServer, wallet: Wallet) {
        Config.setLastFetchedErc20InteractionBlockNumber(0, server: server, wallet: wallet.address)
        Config.setLastFetchedErc721InteractionBlockNumber(0, server: server, wallet: wallet.address)

        PersistantSchedulerStateProvider.resetFetchingState(account: wallet, servers: [server])
    }
}

extension Config {
    private static let migratedToEip1559TransactionsSupportKey = "migratedToEip1559TransactionsSupportKey"

    static var hasMigratedToEip1559TransactionsSupport: Bool {
        let defaults = UserDefaults.standardOrForTests
        return defaults.bool(forKey: migratedToEip1559TransactionsSupportKey)
    }

    static func setAsMigratedToEip1559TransactionsSupport() {
        let defaults = UserDefaults.standardOrForTests
        defaults.set(true, forKey: migratedToEip1559TransactionsSupportKey)
    }
}
