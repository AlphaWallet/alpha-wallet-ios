//
//  TransactionNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import BigInt
import Combine

public final class TransactionNotificationSourceService: NotificationSourceService {
    private let transactionDataStore: TransactionDataStore
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let formatter = EtherNumberFormatter.short
    private static let maximumNumberOfNotifications = 10
    private let receiveNotificationSubject: PassthroughSubject<LocalNotification, Never> = .init()
    private let serversProvider: ServersProvidable
    public weak var delegate: NotificationSourceServiceDelegate?

    public var receiveNotification: AnyPublisher<LocalNotification, Never> {
        receiveNotificationSubject.eraseToAnyPublisher()
    }

    public init(transactionDataStore: TransactionDataStore,
                config: Config,
                serversProvider: ServersProvidable) {

        self.transactionDataStore = transactionDataStore
        self.config = config
        self.serversProvider = serversProvider
    }

    public func start(wallet: Wallet) {
        let predicate = transactionsPredicate(wallet: wallet)

        serversProvider.enabledServersPublisher
            .flatMapLatest { [transactionDataStore] in
                return transactionDataStore.transactionsChangeset(filter: .predicate(predicate), servers: Array($0))
            }.map { changeset -> ServerDictionary<[TransactionInstance]> in
                switch changeset {
                case .initial(let transactions):
                    return TransactionNotificationSourceService.mappedByServer(transactions: transactions)
                case .error:
                    return .init()
                case .update(let transactions, _, let insertions, let modifications):
                    let transactions = insertions.map { transactions[$0] } + modifications.map { transactions[$0] }
                    return TransactionNotificationSourceService.mappedByServer(transactions: transactions)
                }
            }
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverFilteredTransactions in
                for each in serverFilteredTransactions.keys {
                    let transactions = serverFilteredTransactions[each]
                    self?.notifyUserEtherReceived(inNewTransactions: transactions, server: each, wallet: wallet)
                }
            }.store(in: &cancelable)
    }

    private static func mappedByServer(transactions: [TransactionInstance]) -> ServerDictionary<[TransactionInstance]> {
        var serverFilteredTransactions = ServerDictionary<[TransactionInstance]>()
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
    //NOTE: fetch only completed transactions with non zero block number and not older than yesterday
    private func transactionsPredicate(wallet: Wallet) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            TransactionDataStore.functional.blockNumberPredicate(blockNumber: 0),
            TransactionState.predicate(state: .completed),
            NSPredicate(format: "to = '\(wallet.address.eip55String)'"),
            NSPredicate(format: "date > %@", Date.yesterday as NSDate)
        ])
    }

    //TODO notify user of received tokens too
    private func notifyUserEtherReceived(inNewTransactions transactions: [TransactionInstance], server: RPCServer, wallet: Wallet) {
        //Beyond a certain number, it's too noisy and a performance nightmare. Eg. the first time we fetch transactions for a newly imported wallet, we might get 10,000 of them
        let newIncomingEthTransactions: [TransactionInstance] = filterUniqueTransactions(transactions.suffix(TransactionNotificationSourceService.maximumNumberOfNotifications))

        for each in newIncomingEthTransactions {
            guard !config.hasScheduledNotification(for: each, in: wallet) else { continue }

            let amount = formatter.string(from: BigInt(each.value) ?? BigInt(), decimals: 18)

            receiveNotificationSubject.send(.receiveEther(transaction: each.id, amount: amount, server: server))

            config.markScheduledNotification(transaction: each, in: wallet)
        }

        let etherReceived = newIncomingEthTransactions.last.flatMap { BigInt($0.value) }

        switch server.serverWithEnhancedSupport {
        //TODO make this work for other mainnets
        case .main:
            etherReceived.flatMap { delegate?.showCreateBackup(in: self, etherReceived: $0, wallet: wallet) }
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            break
        }
    }

    //Etherscan for Ropsten returns the same transaction twice. Normally Realm will take care of this, but since we are showing user a notification, we don't want to show duplicates
    private func filterUniqueTransactions(_ transactions: [TransactionInstance]) -> [TransactionInstance] {
        var results = [TransactionInstance]()
        for each in transactions where !results.contains(where: { each.id == $0.id }) {
            results.append(each)
        }
        return results
    }
}
