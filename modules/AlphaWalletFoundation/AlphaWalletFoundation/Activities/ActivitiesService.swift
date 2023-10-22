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
import BigInt
import CombineExt

public protocol ActivitiesServiceType: AnyObject {
    var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> { get }
    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> { get }

    func start() async
    func stop() async
    func reinject(activity: Activity) async
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) async -> ActivitiesServiceType
}

typealias ContractsAndCards = [(contract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]
typealias ActivityTokenObjectTokenHolder = (activity: Activity, tokenObject: Token, tokenHolder: TokenHolder)
typealias TokenObjectsAndXMLHandlers = [(contract: AlphaWallet.Address, server: RPCServer, xmlHandler: XMLHandler)]

public actor ActivitiesService: ActivitiesServiceType {
    let sessionsProvider: SessionsProvider
    private let tokensService: TokensService
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    //Dictionary for lookup. Using `.firstIndex` too many times is too slow (60s for 10k events)
    private var activitiesIndexLookup: [Int: (index: Int, activity: Activity)] = [:]
    private var cancellableSet: [AddressAndRPCServer: AnyCancellable] = [:]
    private var activities: [Activity] = []
    private let didUpdateActivitySubject: PassthroughSubject<Activity, Never> = .init()
    private let activitiesSubject: CurrentValueSubject<[ActivityCollection.MappedToDateActivityOrTransaction], Never> = .init([])
    private var cancellable = Set<AnyCancellable>()

    private var wallet: Wallet {
        sessionsProvider.activeSessions.anyValue.account
    }

    private let activitiesFilterStrategy: ActivitiesFilterStrategy
    private let transactionDataStore: TransactionDataStore
    private let transactionsFilterStrategy: TransactionsFilterStrategy

    public nonisolated var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> {
        activitiesSubject.eraseToAnyPublisher()
    }

    public nonisolated var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
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

    public func start() async {
        let transactionsChangeset = sessionsProvider.sessions
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [activitiesSubject] _ in activitiesSubject.send([]) })
            .map { Array($0.keys) }
            .flatMapLatest { [transactionDataStore, transactionsFilterStrategy] in
                transactionDataStore.transactionsChangeset(filter: transactionsFilterStrategy, servers: $0)
            }

        let activities = await activitiesGenerator.generateActivities()

        Publishers.CombineLatest(transactionsChangeset, activities)
            .sink { data in
                Task { [weak self] in
                    await self?.createActivities(activitiesAndTokens: data.1)
                }
            }.store(in: &cancellable)

        didUpdateActivitySubject
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.global())
            .sink { _ in
                Task { [weak self] in
                    await self?.combineActivitiesWithTransactions()
                }
            }.store(in: &cancellable)
    }

    public func stop() async {
        cancellable.cancellAll()
    }

    public func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) async -> ActivitiesServiceType {
        return ActivitiesService(sessionsProvider: sessionsProvider, eventsActivityDataStore: eventsActivityDataStore, transactionDataStore: transactionDataStore, activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilterStrategy, tokensService: tokensService)
    }

    private func createActivities(activitiesAndTokens: [ActivityTokenObjectTokenHolder]) {
        activities = activitiesAndTokens.compactMap { $0.activity }.sorted { $0.blockNumber > $1.blockNumber }
        updateActivitiesIndexLookup(with: activities)

        combineActivitiesWithTransactions()

        for (activity, token, tokenHolder) in activitiesAndTokens {
            refreshActivity(token: token, tokenHolder: tokenHolder, activity: activity)
        }
    }

    public func reinject(activity: Activity) async {
        guard let tokenHolders = await activitiesGenerator.tokensAndTokenHolders[activity.token.addressAndRPCServer] else { return }
        refreshActivity(token: activity.token, tokenHolder: tokenHolders[0], activity: activity)
    }

    private func combineActivitiesWithTransactions() {
        Task { @MainActor in
            let transactions = await transactionDataStore.transactions(forFilter: transactionsFilterStrategy, servers: Array(sessionsProvider.activeSessions.keys), oldestBlockNumber: activities.last?.blockNumber)
            let items = await combine(activities: activities, with: transactions)
            let activities = ActivityCollection.sorted(activities: items)
            activitiesSubject.send(activities)
        }
    }

    //Combining includes filtering around activities (from events) for ERC20 send/receive transactions which are already covered by transactions
    private func combine(activities: [Activity], with transactions: [Transaction]) async -> [ActivityRowModel] {
        let all: [ActivityOrTransactionInstance] = activities.map { .activity($0) } + transactions.map { .transaction($0) }
        let sortedAll: [ActivityOrTransactionInstance] = all.sorted { $0.blockNumber < $1.blockNumber }
        let counters = Dictionary(grouping: sortedAll, by: \.blockNumber)

        return await counters.asyncMap {
            await generateRowModels(activityOrTransactions: $0.value, blockNumber: $0.key)
        }.flatMap { $0 }
    }

    private func generateRowModels(activityOrTransactions: [ActivityOrTransactionInstance], blockNumber: Int) async -> [ActivityRowModel] {
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
                let activity = await functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensService: tokensService, wallet: wallet.address)
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

                    results.append(contentsOf: await transaction.localizedOperations.asyncMap {
                        let activity = await functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), tokensService: tokensService, wallet: wallet.address)
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
                let activity = await functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensService: tokensService, wallet: wallet.address)
                if transaction.localizedOperations.isEmpty {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else if transaction.localizedOperations.count == 1 {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else {
                    let isSwap = self.isSwap(activities: activities, operations: transaction.localizedOperations, wallet: wallet)
                    var results: [ActivityRowModel] = .init()
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: .init()))
                    results.append(contentsOf: await transaction.localizedOperations.asyncMap {
                        let activity = await functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), tokensService: tokensService, wallet: wallet.address)

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

    private func updatedActivityWithResolvedValues(token: Token, tokenHolder: TokenHolder, activity: Activity, resolvedAttributeNameValues: [AttributeId: AssetInternalValue]) {
        //NOTE: Fix crash when element with index out of range
        if let (index, oldActivity) = activitiesIndexLookup[activity.id] {
            let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
            let updatedActivity: Activity = .init(id: oldActivity.id, rowType: oldActivity.rowType, token: token, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, transactionIndex: oldActivity.transactionIndex, logIndex: oldActivity.logIndex, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView, isBaseCard: oldActivity.isBaseCard, state: oldActivity.state)

            if activities.indices.contains(index) {
                activities[index] = updatedActivity
                didUpdateActivitySubject.send(updatedActivity)
            }
        } else {
            //no-op. We should be able to find it unless the list of activities has changed
        }
    }

    //Important to pass in the `TokenHolder` instance and not re-create so that we don't override the subscribable values for the token with ones that are not resolved yet
    private func refreshActivity(token: Token, tokenHolder: TokenHolder, activity: Activity) {
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        cancellableSet[token.addressAndRPCServer] = attributeValues.resolveAllAttributes()
            .sink(receiveValue: { [weak self] resolvedAttributeNameValues in
                guard let strongSelf = self else { return }
                Task { [weak self] in
                    await self?.updatedActivityWithResolvedValues(token: token, tokenHolder: tokenHolder, activity: activity, resolvedAttributeNameValues: resolvedAttributeNameValues)
                }
            })
    }

    //We can't run this in `activities` didSet {} because this will then be run unnecessarily, when we refresh each activity (we only want this to update when we refresh the entire activity list)
    private func updateActivitiesIndexLookup(with activities: [Activity]) {
        var newValue: [Int: (index: Int, activity: Activity)] = [:]
        for (index, each) in activities.enumerated() {
            newValue[each.id] = (index, each)
        }
        activitiesIndexLookup = newValue
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

fileprivate extension ActivitiesService.functional {
    static func extractTokenAndActivityName(fromTransactionRow transactionRow: TransactionRow, tokensService: TokensService, wallet: AlphaWallet.Address) async -> (token: Token, activityName: String)? {
        enum TokenOperation {
            case nativeCryptoTransfer(Token)
            case completedTransfer(Token)
            case pendingTransfer(Token)
            case completedErc20Approval(Token)
            case pendingErc20Approval(Token)

            var token: Token {
                switch self {
                case .nativeCryptoTransfer(let token):
                    return token
                case .completedTransfer(let token):
                    return token
                case .pendingTransfer(let token):
                    return token
                case .completedErc20Approval(let token):
                    return token
                case .pendingErc20Approval(let token):
                    return token
                }
            }
        }

        let erc20TokenOperation: TokenOperation?
        if transactionRow.operation == nil {
            erc20TokenOperation = .nativeCryptoTransfer(MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionRow.server))
        } else {
            //Explicitly listing out combinations so future changes to enums will be caught by compiler
            switch (transactionRow.state, transactionRow.operation?.operationType) {
            case (.pending, .nativeCurrencyTokenTransfer), (.pending, .erc20TokenTransfer), (.pending, .erc721TokenTransfer), (.pending, .erc875TokenTransfer), (.pending, .erc1155TokenTransfer):
                if let address = transactionRow.operation?.contractAddress {
                    erc20TokenOperation = await tokensService.token(for: address, server: transactionRow.server).flatMap { TokenOperation.pendingTransfer($0) }
                } else {
                    erc20TokenOperation = nil
                }
            case (.completed, .nativeCurrencyTokenTransfer), (.completed, .erc20TokenTransfer), (.completed, .erc721TokenTransfer), (.completed, .erc875TokenTransfer), (.completed, .erc1155TokenTransfer):
                if let address = transactionRow.operation?.contractAddress {
                    erc20TokenOperation =  await tokensService.token(for: address, server: transactionRow.server) .flatMap { TokenOperation.completedTransfer($0) }
                } else {
                    erc20TokenOperation = nil
                }
            case (.pending, .erc20TokenApprove):
                if let address = transactionRow.operation?.contractAddress {
                    erc20TokenOperation = await tokensService.token(for: address, server: transactionRow.server) .flatMap { TokenOperation.pendingErc20Approval($0) }
                } else {
                    erc20TokenOperation = nil
                }
            case (.completed, .erc20TokenApprove):
                if let address = transactionRow.operation?.contractAddress {
                    erc20TokenOperation = await tokensService.token(for: address, server: transactionRow.server) .flatMap { TokenOperation.completedErc20Approval($0) }
                } else {
                    erc20TokenOperation = nil
                }
            case (.pending, .erc721TokenApproveAll):
                //TODO support ERC721 setApprovalForAll()
                erc20TokenOperation = .none
            case (.completed, .erc721TokenApproveAll):
                //TODO support ERC721 setApprovalForAll()
                erc20TokenOperation = .none
            case (.unknown, _), (.error, _), (.failed, _), (_, .unknown), (.completed, .none), (.pending, nil):
                erc20TokenOperation = .none
            }
        }
        guard let token = erc20TokenOperation?.token else { return nil }
        let activityName: String
        switch erc20TokenOperation {
        case .nativeCryptoTransfer, .completedTransfer, .pendingTransfer, .none:
            if wallet.sameContract(as: transactionRow.from) {
                activityName = "sent"
            } else {
                activityName = "received"
            }
        case .completedErc20Approval, .pendingErc20Approval:
            activityName = "ownerApproved"
        }
        return (token: token, activityName: activityName)
    }

    static func createPseudoActivity(fromTransactionRow transactionRow: TransactionRow, tokensService: TokensService, wallet: AlphaWallet.Address) async -> Activity? {
        guard let (token, activityName) = await extractTokenAndActivityName(fromTransactionRow: transactionRow, tokensService: tokensService, wallet: wallet) else { return nil }

        var cardAttributes = [AttributeId: AssetInternalValue]()
        cardAttributes.setSymbol(string: transactionRow.server.symbol)

        if let operation = transactionRow.operation, operation.symbol != nil, let value = BigUInt(operation.value) {
            cardAttributes.setAmount(uint: value)
        } else {
            if let value = BigUInt(transactionRow.value) {
                cardAttributes.setAmount(uint: value)
            }
        }

        if let value = AlphaWallet.Address(string: transactionRow.from) {
            cardAttributes.setFrom(address: value)
        }

        if let toString = transactionRow.operation?.to, let to = AlphaWallet.Address(string: toString) {
            cardAttributes.setTo(address: to)
        } else {
            if let value = AlphaWallet.Address(string: transactionRow.to) {
                cardAttributes.setTo(address: value)
            }
        }

        var timestamp: GeneralisedTime = .init()
        timestamp.date = transactionRow.date
        cardAttributes.setTimestamp(generalisedTime: timestamp)
        let state: Activity.State
        switch transactionRow.state {
        case .pending:
            state = .pending
        case .completed:
            state = .completed
        case .error, .failed:
            state = .failed
                //TODO we don't need the other states at the moment
        case .unknown:
            state = .completed
        }
        let rowType: ActivityRowType
        switch transactionRow {
        case .standalone:
            rowType = .standalone
        case .group:
            rowType = .group
        case .item:
            rowType = .item
        }
        return .init(
                //We only use this ID for refreshing the display of specific activity, since the display for ETH send/receives don't ever need to be refreshed, just need a number that don't clash with other activities
                id: transactionRow.blockNumber + 10000000,
                rowType: rowType,
                token: token,
                server: transactionRow.server,
                name: activityName,
                eventName: activityName,
                blockNumber: transactionRow.blockNumber,
                transactionId: transactionRow.id,
                transactionIndex: transactionRow.transactionIndex,
                //We don't use this for transactions, so it's ok
                logIndex: 0,
                date: transactionRow.date,
                values: (token: .init(), card: cardAttributes),
                view: (html: "", urlFragment: nil, style: ""),
                itemView: (html: "", urlFragment: nil, style: ""),
                isBaseCard: true,
                state: state
        )
    }
}
