//
//  ActivitiesService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.05.2021.
//

import Foundation
import Combine
import CoreFoundation
import AlphaWalletCore
import AlphaWalletTokenScript
import CombineExt

public protocol ActivitiesServiceType: AnyObject {
    var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> { get }
    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> { get }

    func start()
    func stop()
    func reinject(activity: Activity)
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType
}

typealias ContractsAndCards = [(contract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]
typealias ActivityTokenObjectTokenHolder = (activity: Activity, tokenObject: Token, tokenHolder: TokenHolder)
typealias TokenObjectsAndXMLHandlers = [(contract: AlphaWallet.Address, server: RPCServer, xmlHandler: XMLHandler)]

public class ActivitiesService: ActivitiesServiceType {
    let sessionsProvider: SessionsProvider
    private let tokensService: TokensService
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    //Dictionary for lookup. Using `.firstIndex` too many times is too slow (60s for 10k events)
    private var activitiesIndexLookup: AtomicDictionary<Int, (index: Int, activity: Activity)> = .init()
    private var cancellableSet: AtomicDictionary<AddressAndRPCServer, AnyCancellable> = .init()
    private var activities: AtomicArray<Activity> = .init()
    private let didUpdateActivitySubject: PassthroughSubject<Activity, Never> = .init()
    private let activitiesSubject: CurrentValueSubject<[ActivityCollection.MappedToDateActivityOrTransaction], Never> = .init([])
    private var cancellable = Set<AnyCancellable>()

    private var wallet: Wallet {
        sessionsProvider.activeSessions.anyValue.account
    }

    private let activitiesFilterStrategy: ActivitiesFilterStrategy
    private let transactionDataStore: TransactionDataStore
    private let transactionsFilterStrategy: TransactionsFilterStrategy

    public var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> {
        activitiesSubject.eraseToAnyPublisher()
    }

    public var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        didUpdateActivitySubject.eraseToAnyPublisher()
    }

    private let activitiesGenerator: ActivitiesGenerator

    init(sessionsProvider: SessionsProvider,
         eventsActivityDataStore: EventsActivityDataStoreProtocol,
         transactionDataStore: TransactionDataStore,
         activitiesFilterStrategy: ActivitiesFilterStrategy = .none,
         transactionsFilterStrategy: TransactionsFilterStrategy = .all,
         tokensService: TokensService) {

        self.sessionsProvider = sessionsProvider
        self.eventsActivityDataStore = eventsActivityDataStore
        self.activitiesFilterStrategy = activitiesFilterStrategy
        self.transactionDataStore = transactionDataStore
        self.transactionsFilterStrategy = transactionsFilterStrategy
        self.tokensService = tokensService

        self.activitiesGenerator = ActivitiesGenerator(
            sessionsProvider: sessionsProvider,
            transactionsFilterStrategy: transactionsFilterStrategy,
            activitiesFilterStrategy: activitiesFilterStrategy,
            tokensService: tokensService,
            eventsActivityDataStore: eventsActivityDataStore)
    }

    public func start() {
        let transactionsChangeset = sessionsProvider.sessions
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [activitiesSubject] _ in activitiesSubject.send([]) })
            .map { Array($0.keys) }
            .flatMapLatest { [transactionDataStore, transactionsFilterStrategy] in
                transactionDataStore.transactionsChangeset(filter: transactionsFilterStrategy, servers: $0)
            }

        let activities = activitiesGenerator.generateActivities()

        Publishers.CombineLatest(transactionsChangeset, activities)
            .sink { [weak self] data in self?.createActivities(activitiesAndTokens: data.1) }
            .store(in: &cancellable)

        didUpdateActivitySubject
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.global())
            .sink { [weak self] _ in
                self?.combineActivitiesWithTransactions()
            }.store(in: &cancellable)
    }

    public func stop() {
        cancellable.cancellAll()
    }

    public func copy(activitiesFilterStrategy: ActivitiesFilterStrategy,
                     transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType {

        return ActivitiesService(
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            transactionDataStore: transactionDataStore,
            activitiesFilterStrategy: activitiesFilterStrategy,
            transactionsFilterStrategy: transactionsFilterStrategy,
            tokensService: tokensService)
    }

    private func createActivities(activitiesAndTokens: [ActivityTokenObjectTokenHolder]) {
        activities.set(array: activitiesAndTokens.compactMap { $0.activity }.sorted { $0.blockNumber > $1.blockNumber })
        updateActivitiesIndexLookup(with: activities.all)

        combineActivitiesWithTransactions()

        for (activity, token, tokenHolder) in activitiesAndTokens {
            refreshActivity(token: token, tokenHolder: tokenHolder, activity: activity)
        }
    }

    public func reinject(activity: Activity) {
        guard let tokenHolders = activitiesGenerator.tokensAndTokenHolders[activity.token.addressAndRPCServer] else { return }

        refreshActivity(token: activity.token, tokenHolder: tokenHolders[0], activity: activity)
    }

    private func combineActivitiesWithTransactions() {
        let transactions = transactionDataStore.transactions(
            forFilter: transactionsFilterStrategy,
            servers: Array(sessionsProvider.activeSessions.keys),
            oldestBlockNumber: activities.last?.blockNumber)

        let items = combine(activities: activities.all, with: transactions)
        let activities = ActivityCollection.sorted(activities: items)

        activitiesSubject.send(activities)
    }

    //Combining includes filtering around activities (from events) for ERC20 send/receive transactions which are already covered by transactions
    private func combine(activities: [Activity], with transactions: [Transaction]) -> [ActivityRowModel] {
        let all: [ActivityOrTransactionInstance] = activities.map { .activity($0) } + transactions.map { .transaction($0) }
        let sortedAll: [ActivityOrTransactionInstance] = all.sorted { $0.blockNumber < $1.blockNumber }
        let counters = Dictionary(grouping: sortedAll, by: \.blockNumber)

        return counters.map {
            generateRowModels(activityOrTransactions: $0.value, blockNumber: $0.key)
        }.flatMap { $0 }
    }

    private func generateRowModels(activityOrTransactions: [ActivityOrTransactionInstance], blockNumber: Int) -> [ActivityRowModel] {
        if activityOrTransactions.isEmpty {
            //Shouldn't be possible
            return .init()
        } else if activityOrTransactions.count > 1 {
            let activities: [Activity] = activityOrTransactions.compactMap(\.activity)
            //TODO will we ever have more than 1 transaction object (not activity/event) in the database for the same block number? Maybe if we get 1 from normal Etherscan endpoint and another from Etherscan ERC20 history endpoint?
            if let transaction: Transaction = activityOrTransactions.compactMap(\.transaction).first {
                var results: [ActivityRowModel] = .init()
                let activities: [Activity] = activities.filter { activity in
                    let operations = transaction.localizedOperations
                    return operations.allSatisfy { activity != $0 }
                }
                let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensService: tokensService, wallet: wallet.address)
                if transaction.localizedOperations.isEmpty && activities.isEmpty {
                    results.append(.standaloneTransaction(transaction: transaction, activity: activity))
                } else if transaction.localizedOperations.count == 1, transaction.value == "0", activities.isEmpty {
                    results.append(.standaloneTransaction(transaction: transaction, activity: activity))
                } else if transaction.localizedOperations.isEmpty && activities.count == 1 {
                    results.append(.parentTransaction(transaction: transaction, isSwap: false, activities: activities))
                    results.append(contentsOf: activities.map { .childActivity(transaction: transaction, activity: $0) })
                } else {
                    let isSwap = self.isSwap(activities: activities, operations: transaction.localizedOperations, wallet: wallet)
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: activities))

                    results.append(contentsOf: transaction.localizedOperations.map {
                        let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), tokensService: tokensService, wallet: wallet.address)
                        return .childTransaction(transaction: transaction, operation: $0, activity: activity)
                    })
                    for each in activities {
                        results.append(.childActivity(transaction: transaction, activity: each))
                    }
                }
                return results
            } else {
                //TODO we should have a group here too to wrap activities with the same block number. No transaction, so more work
                return activities.map { .standaloneActivity(activity: $0) }
            }
        } else {
            switch activityOrTransactions.first {
            case .activity(let activity):
                return [.standaloneActivity(activity: activity)]
            case .transaction(let transaction):
                let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensService: tokensService, wallet: wallet.address)
                if transaction.localizedOperations.isEmpty {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else if transaction.localizedOperations.count == 1 {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else {
                    let isSwap = self.isSwap(activities: activities.all, operations: transaction.localizedOperations, wallet: wallet)
                    var results: [ActivityRowModel] = .init()
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: .init()))
                    results.append(contentsOf: transaction.localizedOperations.map {
                        let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), tokensService: tokensService, wallet: wallet.address)

                        return .childTransaction(transaction: transaction, operation: $0, activity: activity)
                    })
                    return results
                }
            case .none:
                return .init()
            }
        }
    }

    private func isSwap(activities: [Activity], operations: [LocalizedOperation], wallet: Wallet) -> Bool {
        //Might have other transactions like approved embedded, so we can't check for all send and receives.
        let hasSend = activities.contains { $0.isSend } || operations.contains { $0.isSend(from: wallet.address) }
        let hasReceive = activities.contains { $0.isReceive } || operations.contains { $0.isReceived(by: wallet.address) }
        return hasSend && hasReceive
    }

    //Important to pass in the `TokenHolder` instance and not re-create so that we don't override the subscribable values for the token with ones that are not resolved yet
    private func refreshActivity(token: Token, tokenHolder: TokenHolder, activity: Activity) {
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        cancellableSet[token.addressAndRPCServer] = attributeValues.resolveAllAttributes()
            .sink(receiveValue: { [weak self] resolvedAttributeNameValues in
                guard let stronSelf = self else { return }

                //NOTE: Fix crush when element with index out of range
                if let (index, oldActivity) = stronSelf.activitiesIndexLookup[activity.id] {
                    let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
                    let updatedActivity: Activity = .init(id: oldActivity.id, rowType: oldActivity.rowType, token: token, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, transactionIndex: oldActivity.transactionIndex, logIndex: oldActivity.logIndex, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView, isBaseCard: oldActivity.isBaseCard, state: oldActivity.state)

                    if stronSelf.activities.contains(index: index) {
                        stronSelf.activities[index] = updatedActivity

                        stronSelf.didUpdateActivitySubject.send(updatedActivity)
                    }
                } else {
                    //no-op. We should be able to find it unless the list of activities has changed
                }
            })
    }

    //We can't run this in `activities` didSet {} because this will then be run unnecessarily, when we refresh each activity (we only want this to update when we refresh the entire activity list)
    private func updateActivitiesIndexLookup(with activities: [Activity]) {
        var newValue: [Int: (index: Int, activity: Activity)] = [:]
        for (index, each) in activities.enumerated() {
            newValue[each.id] = (index, each)
        }
        activitiesIndexLookup.set(value: newValue)
    }
}

fileprivate func == (activity: Activity, operation: LocalizedOperation) -> Bool {
    func isSameFrom() -> Bool {
        guard let from = activity.values.card["from"]?.addressValue, from.sameContract(as: operation.from) else { return false }
        return true
    }

    func isSameTo() -> Bool {
        guard let to = activity.values.card["to"]?.addressValue, to.sameContract(as: operation.to) else { return false }
        return true
    }

    func isSameAmount() -> Bool {
        guard let amount = activity.values.card["amount"]?.uintValue, String(amount) == operation.value else { return false }
        return true
    }

    guard let symbol = activity.values.token["symbol"]?.stringValue, symbol == operation.symbol else { return false }
    let sameOperation: Bool = {
        switch operation.operationType {
        case .nativeCurrencyTokenTransfer:
            //TODO not possible to hit this since we can't have an activity (event) for crypto send/received?
            return activity.nativeViewType == .nativeCryptoSent || activity.nativeViewType == .nativeCryptoReceived
        case .erc20TokenTransfer:
            return (activity.nativeViewType == .erc20Sent || activity.nativeViewType == .erc20Received) && isSameAmount() && isSameFrom() && isSameTo()
            //TODO name seems wrong since it's checking for ERC721 approvals too
        case .erc20TokenApprove:
            return activity.nativeViewType == .erc20OwnerApproved || activity.nativeViewType == .erc20ApprovalObtained || activity.nativeViewType == .erc721OwnerApproved || activity.nativeViewType == .erc721ApprovalObtained
        case .erc721TokenTransfer, .erc1155TokenTransfer:
            return (activity.nativeViewType == .erc721Sent || activity.nativeViewType == .erc721Received) && isSameAmount() && isSameFrom() && isSameTo()
        case .erc721TokenApproveAll:
            //TODO support ERC721 setApprovalForAll()
            return false
        case .erc875TokenTransfer:
            return false
        case .unknown:
            return false
        }
    }()
    guard sameOperation else { return false }
    return true
}

fileprivate func != (activity: Activity, operation: LocalizedOperation) -> Bool {
    !(activity == operation)
}

extension ActivitiesService {
    enum functional {}
}

extension ActivitiesService.functional {
    static func generateImplicitAttributesForCard(forContract contract: AlphaWallet.Address, server: RPCServer, event: EventActivityInstance) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        var timestamp: GeneralisedTime = .init()
        timestamp.date = event.date
        results["timestamp"] = .generalisedTime(timestamp)
        return results
    }
}
