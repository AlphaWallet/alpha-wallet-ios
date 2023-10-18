//
//  TransactionNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

public final class TransactionNotificationSource: LocalNotificationSource {
    private static let maximumNumberOfNotifications = 10

    private let config: WalletConfig
    private var cancelable: AnyCancellable?
    private let subject: PassthroughSubject<LocalNotification, Never> = .init()
    private let wallet: Wallet
    private let transactionsService: TransactionsService

    public var receiveNotification: AnyPublisher<LocalNotification, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(transactionsService: TransactionsService,
                config: WalletConfig,
                wallet: Wallet) {

        self.wallet = wallet
        self.transactionsService = transactionsService
        self.config = config
    }

    public func stop() {
        cancelable?.cancel()
    }

    public func buildNotifications(transactions: [Transaction]) -> [LocalNotification] {
        TransactionNotificationSource.functional.buildNotifications(transactions: transactions)
    }

    public func start() {
        stop()
        let predicate = TransactionNotificationSource.functional.transactionsPredicate(wallet: wallet)

        cancelable = transactionsService.transactions(filter: .predicate(predicate))
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.scheduleLocalNotifications(transactions: $0) }
    }

    private func scheduleLocalNotifications(transactions: [Transaction]) {
        let notifications = buildNotifications(transactions: transactions)
        //Beyond a certain number, it's too noisy and a performance nightmare. Eg. the first time we fetch transactions for a newly imported wallet, we might get 10,000 of them
        for each in notifications.suffix(TransactionNotificationSource.maximumNumberOfNotifications) {
            guard !config.hasScheduledNotification(key: each.id) else { continue }

            subject.send(each)
            config.markScheduledNotification(key: each.id)
        }
    }
}

extension TransactionNotificationSource {
    enum functional {}
}

fileprivate extension TransactionNotificationSource.functional {
    //NOTE: case insensitive search for address value because it might be written not in eip55
    static func addressPredicate(field: String, address: AlphaWallet.Address) -> NSPredicate {
        return NSPredicate(format: "\(field) contains[c] %@", address.eip55String)
    }

    //NOTE: fetch only completed transactions with non zero block number and not older than yesterday
    static func transactionsPredicate(wallet: Wallet) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            TransactionDataStore.functional.blockNumberPredicate(blockNumber: 0),
            TransactionState.predicate(state: .completed),
            TransactionNotificationSource.functional.addressPredicate(field: "to", address: wallet.address),
            NSPredicate(format: "date > %@", Date.yesterday as NSDate)
        ])
    }

    static func buildNotifications(transactions: [Transaction]) -> [LocalNotification] {
        let transactions = TransactionNotificationSource.functional.filterUniqueTransactions(transactions)
        return transactions.compactMap { tx -> LocalNotification? in
            if let operation = tx.operation, let amount = Decimal(bigUInt: BigUInt(operation.value) ?? BigUInt(), decimals: operation.decimals) {
                let symbol = operation.symbol ?? tx.server.symbol
                let tokenType: TokenType
                switch operation.operationType {
                case .erc1155TokenTransfer:
                    tokenType = .erc1155
                case .erc20TokenTransfer:
                    tokenType = .erc20
                case .erc721TokenTransfer:
                    tokenType = .erc721
                case .nativeCurrencyTokenTransfer:
                    tokenType = .nativeCryptocurrency
                default:
                    return nil
                }
                guard let wallet = AlphaWallet.Address(string: tx.to) else { return nil }

                return .receiveToken(transaction: tx.id, amount: amount, tokenType: tokenType, symbol: symbol, wallet: wallet, server: tx.server)
            } else if let amount = Decimal(bigUInt: BigUInt(tx.value) ?? BigUInt(), decimals: tx.server.decimals) {
                guard let wallet = AlphaWallet.Address(string: tx.to) else { return nil }
                let symbol = tx.server.symbol
                return .receiveEther(transaction: tx.id, amount: amount, wallet: wallet, server: tx.server)
            } else {
                return nil
            }
        }
    }

    //Etherscan for Ropsten returns the same transaction twice. Normally Realm will take care of this, but since we are showing user a notification, we don't want to show duplicates
    static func filterUniqueTransactions(_ transactions: [Transaction]) -> [Transaction] {
        var results = [Transaction]()
        for each in transactions where !results.contains(where: { each.id == $0.id }) {
            results.append(each)
        }
        return results
    }

    static func mappedByServer(transactions: [Transaction]) -> ServerDictionary<[Transaction]> {
        var serverFilteredTransactions = AlphaWalletFoundation.ServerDictionary<[Transaction]>()
        let tsx = transactions
        for each in tsx {
            if let value = serverFilteredTransactions[safe: each.server] {
                serverFilteredTransactions[each.server] = value + [each]
            } else {
                serverFilteredTransactions[each.server] = [each]
            }
        }

        return serverFilteredTransactions
    }
}

extension WalletConfig {

    private static func notificationsStorageKey() -> String {
        return "presentedNotifications"
    }

    func hasScheduledNotification(key: String) -> Bool {
        return notifications().contains(key)
    }

    private func notifications() -> [String] {
        let storageKey = WalletConfig.notificationsStorageKey()
        if let values = defaults.array(forKey: storageKey) {
            return values as! [String]
        } else {
            return []
        }
    }

    func markScheduledNotification(key: String) {
        let notifications = notifications()
        let updatedNotifications = Array(Set(notifications + [key]))

        let storageKey = WalletConfig.notificationsStorageKey()
        defaults.set(updatedNotifications, forKey: storageKey)
    }

    func removeAllNotifications(for wallet: Wallet) {
        let storageKey = WalletConfig.notificationsStorageKey()
        defaults.removeObject(forKey: storageKey)
    }
}
