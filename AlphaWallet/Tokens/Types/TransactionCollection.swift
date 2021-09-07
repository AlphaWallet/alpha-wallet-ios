//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import PromiseKit

class FilterInSingleTransactionsStorage: Equatable, Hashable {
    let filter: (TransactionInstance) -> Bool
    let transactionsStorage: TransactionsStorage
    private let uuid: UUID

    init(transactionsStorage: TransactionsStorage, filter: @escaping (TransactionInstance) -> Bool) {
        self.filter = filter
        self.transactionsStorage = transactionsStorage
        uuid = UUID()
    }

    static func == (lhs: FilterInSingleTransactionsStorage, rhs: FilterInSingleTransactionsStorage) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
        hasher.combine(transactionsStorage.hashValue)
    }
}

enum TransactionsFilterStrategy: Hashable, CustomStringConvertible {
    case all
    case filter(filter: FilterInSingleTransactionsStorage, tokenObject: TokenObject)

    var description: String {
        switch self {
        case .all:
            return "AT"
        case .filter:
            return "ST"
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .all:
            hasher.combine(1)
        case .filter(let filter, let tokenObject):
            hasher.combine(filter.hashValue)
            hasher.combine(tokenObject.hashValue)
        }
    }
}

protocol TransactionCollectionType: class {
    func add(_ items: [Transaction]) -> [Transaction]
    func subscribableFor(filter: TransactionsFilterStrategy) -> Subscribable<[TransactionInstance]>
    func removeSubscription(subscription: Subscribable<[TransactionInstance]>)
    func transaction(withTransactionId transactionId: String, server: RPCServer) -> TransactionInstance?
}

///This contains transactions across multiple-chains
class TransactionCollection: NSObject, TransactionCollectionType {

    //TODO make private
    let transactionsStorages: [TransactionsStorage]
    private let queue: DispatchQueue

    init(transactionsStorages: [TransactionsStorage], queue: DispatchQueue) {
        self.transactionsStorages = transactionsStorages
        self.queue = queue
        super.init()
    }

    private var cache: [Subscribable<[TransactionInstance]>: [NotificationToken]] = [:]

    func removeSubscription(subscription: Subscribable<[TransactionInstance]>) {
        if let subscriptions = cache[subscription] {
            for s in subscriptions {
                s.invalidate()
            }

            cache[subscription] = nil
        }
    }

    func subscribableFor(filter: TransactionsFilterStrategy) -> Subscribable<[TransactionInstance]> {
        switch filter {
        case .filter(let filterObject, _):
            let mapped = createSingleStorageSubscription(filterObject: filterObject)
            cache[mapped.notifier] = mapped.subscriptions

            return mapped.notifier
        case .all:
            let mapped = createAvailableStoragesSubscription()
            cache[mapped.notifier] = mapped.subscriptions

            return mapped.notifier
        }
    }

    private func createSingleStorageSubscription(filterObject: FilterInSingleTransactionsStorage) -> (notifier: Subscribable<[TransactionInstance]>, subscriptions: [NotificationToken]) {

        let notifier = Subscribable<[TransactionInstance]>(nil)
        let subscription = filterObject.transactionsStorage.objects.observe(on: queue) { change in
            switch change {
            case .initial, .error:
                break
            case .update(let objects, _, _, _):
                notifier.value = Self.filter(results: objects, filterObject: filterObject)
            }
        }

        Promise<[TransactionInstance]> { seal in
            DispatchQueue.main.async {
                //Concatenate arrays of hundreds/thousands of elements. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly
                let values = Array(filterObject.transactionsStorage.objects.map { TransactionInstance(transaction: $0) })
                seal.fulfill(values)
            }
        }.done(on: queue, { trx in
            notifier.value = trx.filter(filterObject.filter)
        }).cauterize()

        return (notifier, [subscription])
    }

    static func filter(results: Results<Transaction>, filterObject: FilterInSingleTransactionsStorage) -> [TransactionInstance] {
        return Array(results.map { TransactionInstance(transaction: $0) }).filter(filterObject.filter)
    }

    private func createAvailableStoragesSubscription() -> (notifier: Subscribable<[TransactionInstance]>, subscriptions: [NotificationToken]) {
        let notifier = Subscribable<[TransactionInstance]>(nil)
        var subscriptions: [NotificationToken] = []

        for store in transactionsStorages {
            let subscription = store.objects.observe(on: queue) { [weak self] change in
                guard let strongSelf = self else { return }

                switch change {
                case .initial, .error:
                    break
                //NOTE: we don't want to fire trigger initial change event for each storage
                // and fire it only once. All lates updates will be fired for each storage
                case .update:
                    strongSelf.objects.done(on: strongSelf.queue, { transactions in
                        notifier.value = transactions
                    }).cauterize()
                }
            }

            subscriptions.append(subscription)
        }

        objects.done(on: queue, { transactions in
            notifier.value = transactions
        }).cauterize()

        return (notifier, subscriptions)
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard let server = items.first?.server else { return [] }
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return [] }
        return storage.add(items)
    }

    private var objects: Promise<[TransactionInstance]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                //Concatenate arrays of hundreds/thousands of elements. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly
                let values = strongSelf.transactionsStorages.map { $0.objects }.flatMap { $0 }.map { TransactionInstance(transaction: $0) }
                seal.fulfill(values)
            }
        }
    }

    func transaction(withTransactionId transactionId: String, server: RPCServer) -> TransactionInstance? {
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return nil }
        return storage.transaction(withTransactionId: transactionId)
    }
}
