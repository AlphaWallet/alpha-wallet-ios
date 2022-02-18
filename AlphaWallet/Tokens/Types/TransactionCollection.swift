//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import PromiseKit 

enum TransactionsFilterStrategy {
    case all
    case filter(transactionsStorage: TransactionsStorage, strategy: ActivitiesFilterStrategy, tokenObject: TokenObject)
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
        case .filter(let transactionsStorage, let filterObject, _):
            let mapped = createSingleStorageSubscription(transactionsStorage: transactionsStorage, filterObject: filterObject)
            cache[mapped.notifier] = mapped.subscriptions

            return mapped.notifier
        case .all:
            let mapped = createAvailableStoragesSubscription()
            cache[mapped.notifier] = mapped.subscriptions

            return mapped.notifier
        }
    }

    private func createSingleStorageSubscription(transactionsStorage: TransactionsStorage, filterObject: ActivitiesFilterStrategy) -> (notifier: Subscribable<[TransactionInstance]>, subscriptions: [NotificationToken]) {

        let notifier = Subscribable<[TransactionInstance]>(nil)

        let subscription = transactionsStorage
            .objects
            .filter(filterObject.predicate)
            .observe(on: queue) { change in
                switch change {
                case .initial, .error:
                    break
                case .update(let objects, _, _, _):
                    notifier.value = Array(objects.map { TransactionInstance(transaction: $0) })
                }
            }

        Promise<[TransactionInstance]> { seal in
            DispatchQueue.main.async {
                //Concatenate arrays of hundreds/thousands of elements. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly
                let values = transactionsStorage
                    .objects
                    .filter(filterObject.predicate)
                    .map { TransactionInstance(transaction: $0) }
                seal.fulfill(Array(values))
            }
        }.done(on: queue, { trx in
            notifier.value = trx
        }).cauterize()

        return (notifier, [subscription])
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
