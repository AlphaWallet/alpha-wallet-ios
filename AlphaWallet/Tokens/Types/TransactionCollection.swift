//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift

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
    case filter(filter: FilterInSingleTransactionsStorage)

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
        case .filter(let filter):
            hasher.combine(filter.hashValue)
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
        case .filter(let filterObject):
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

        queue.async {
            notifier.value = Self.filter(results: filterObject.transactionsStorage.objects, filterObject: filterObject)
        }

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
                    notifier.value = strongSelf.objects
                }
            }

            subscriptions.append(subscription)
        }

        queue.async {
            notifier.value = self.objects
        }

        return (notifier, subscriptions)
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard let server = items.first?.server else { return [] }
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return [] }
        return storage.add(items)
    }

    var objects: [TransactionInstance] {
        //Concatenate arrays of hundreds/thousands of elements. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly
        return transactionsStorages.flatMap {
            return $0.objects.map { TransactionInstance(transaction: $0) }
        }
    }

    func transaction(withTransactionId transactionId: String, server: RPCServer) -> TransactionInstance? {
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return nil }
        return storage.transaction(withTransactionId: transactionId)
    }
}
