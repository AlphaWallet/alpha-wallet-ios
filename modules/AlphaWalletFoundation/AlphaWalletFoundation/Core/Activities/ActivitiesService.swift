//
//  ActivitiesService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.05.2021.
//

import Foundation
import CoreFoundation
import Combine

public protocol ActivitiesServiceType: class {
    var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> { get }
    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> { get }

    func start()
    func reinject(activity: Activity)
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType
}

public class ActivitiesService: NSObject, ActivitiesServiceType {
    private typealias ContractsAndCards = [(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]
    private typealias ActivityTokenObjectTokenHolder = (activity: Activity, tokenObject: Token, tokenHolder: TokenHolder)
    private typealias TokenObjectsAndXMLHandlers = [(contract: AlphaWallet.Address, server: RPCServer, xmlHandler: XMLHandler)]

    private let config: Config
    let sessions: ServerDictionary<WalletSession>
    private let tokensService: TokenProvidable

    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    private let eventsDataStore: NonActivityEventsDataStore
    //Dictionary for lookup. Using `.firstIndex` too many times is too slow (60s for 10k events)
    private var activitiesIndexLookup: AtomicDictionary<Int, (index: Int, activity: Activity)> = .init()
    private var activities: AtomicArray<Activity> = .init()

    private var tokensAndTokenHolders: AtomicDictionary<AddressAndRPCServer, [TokenHolder]> = .init()
    private var rateLimitedViewControllerReloader: RateLimiter?
    private var hasLoadedActivitiesTheFirstTime = false

    private let didUpdateActivitySubject: PassthroughSubject<Activity, Never> = .init()
    private let activitiesSubject: CurrentValueSubject<[ActivityCollection.MappedToDateActivityOrTransaction], Never> = .init([])

    private var wallet: Wallet {
        sessions.anyValue.account
    }

    private let activitiesFilterStrategy: ActivitiesFilterStrategy
    private let transactionDataStore: TransactionDataStore
    private let transactionsFilterStrategy: TransactionsFilterStrategy
    private var cancelable = Set<AnyCancellable>()

    public var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> {
        activitiesSubject.eraseToAnyPublisher()
    }

    public var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        didUpdateActivitySubject.eraseToAnyPublisher()
    }

    init(
        config: Config,
        sessions: ServerDictionary<WalletSession>,
        assetDefinitionStore: AssetDefinitionStore,
        eventsActivityDataStore: EventsActivityDataStoreProtocol,
        eventsDataStore: NonActivityEventsDataStore,
        transactionDataStore: TransactionDataStore,
        activitiesFilterStrategy: ActivitiesFilterStrategy = .none,
        transactionsFilterStrategy: TransactionsFilterStrategy = .all,
        tokensService: TokenProvidable
    ) {
        self.config = config
        self.sessions = sessions
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.eventsActivityDataStore = eventsActivityDataStore
        self.activitiesFilterStrategy = activitiesFilterStrategy
        self.transactionDataStore = transactionDataStore
        self.transactionsFilterStrategy = transactionsFilterStrategy
        self.tokensService = tokensService
        super.init()
    }

    public func start() {
        let transactionsChangeset = transactionDataStore
            .transactionsChangeset(forFilter: transactionsFilterStrategy, servers: config.enabledServers)
            .mapToVoid()
            .eraseToAnyPublisher()

        let eventsActivity = eventsActivityDataStore
            .recentEventsChangeset
            .mapToVoid()
            .eraseToAnyPublisher()

        Publishers.Merge(transactionsChangeset, eventsActivity)
            .sink { [weak self] _ in self?.createActivities() }
            .store(in: &cancelable)
    }

    public func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType {
        return ActivitiesService(config: config, sessions: sessions, assetDefinitionStore: assetDefinitionStore, eventsActivityDataStore: eventsActivityDataStore, eventsDataStore: eventsDataStore, transactionDataStore: transactionDataStore, activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilterStrategy, tokensService: tokensService)
    }

    private func getTokensAndXmlHandlers(forTokens tokens: [Token]) -> TokenObjectsAndXMLHandlers {
        return tokens.compactMap { each in
            let xmlHandler = XMLHandler(token: each, assetDefinitionStore: self.assetDefinitionStore)
            guard xmlHandler.hasAssetDefinition else { return nil }
            guard xmlHandler.server?.matches(server: each.server) ?? false else { return nil }

            return (contract: each.contractAddress, server: each.server, xmlHandler: xmlHandler)
        }
    }

    private func getContractsAndCards(contractServerXmlHandlers: ActivitiesService.TokenObjectsAndXMLHandlers) -> ContractsAndCards {
        let contractsAndCardsOptional: [ContractsAndCards] = contractServerXmlHandlers.compactMap { eachContract, _, xmlHandler in
            var contractAndCard: ContractsAndCards = .init()
            for card in xmlHandler.activityCards {
                let (filterName, filterValue) = card.eventOrigin.eventFilter
                let interpolatedFilter: String
                if let implicitAttribute = EventSource.functional.convertToImplicitAttribute(string: filterValue) {
                    switch implicitAttribute {
                    case .tokenId:
                        continue
                    case .ownerAddress:
                        interpolatedFilter = "\(filterName)=\(self.wallet.address.eip55String)"
                    case .label, .contractAddress, .symbol:
                        //TODO support more?
                        continue
                    }
                } else {
                    //TODO support things like "$prefix-{tokenId}"
                    continue
                }

                guard let server = xmlHandler.server else { continue }
                switch server {
                case .any:
                    for each in config.enabledServers {
                        contractAndCard.append((tokenContract: eachContract, server: each, card: card, interpolatedFilter: interpolatedFilter))
                    }
                case .server(let server):
                    contractAndCard.append((tokenContract: eachContract, server: server, card: card, interpolatedFilter: interpolatedFilter))
                }
            }
            return contractAndCard
        }
        return contractsAndCardsOptional.flatMap { $0 }
    }

    private func getTokensForActivities() -> [Token] {
        switch transactionsFilterStrategy {
        case .all:
            return tokensService.tokens(for: config.enabledServers)
        case .filter(_, let token):
            return [token]
        case .predicate:
            //NOTE: not supported here
            return []
        }
    }

    private func createActivities() {
        let tokens = getTokensForActivities()
        let tokensAndXmlHandlers = getTokensAndXmlHandlers(forTokens: tokens)
        let contractsAndCards = getContractsAndCards(contractServerXmlHandlers: tokensAndXmlHandlers)
        let activitiesAndTokens = getActivitiesAndTokens(contractsAndCards: contractsAndCards)

        activities.set(array: activitiesAndTokens.compactMap { $0.activity }.sorted { $0.blockNumber > $1.blockNumber })
        updateActivitiesIndexLookup(with: activities.array)

        reloadViewController(reloadImmediately: true)

        for (activity, token, tokenHolder) in activitiesAndTokens {
            refreshActivity(token: token, tokenHolder: tokenHolder, activity: activity)
        }
    }

    private func getActivitiesAndTokens(contractsAndCards: ContractsAndCards) -> [ActivitiesService.ActivityTokenObjectTokenHolder] {
        var activitiesAndTokens: [ActivityTokenObjectTokenHolder] = .init()
        //NOTE: here is a lot of calculations, `contractsAndCards` could reach up of 1000 items, as well as recentEvents could reach 1000.Simply it call inner function 1 000 000 times
        for (eachContract, eachServer, card, interpolatedFilter) in contractsAndCards {
            let activities = getActivities(forTokenContract: eachContract, server: eachServer, card: card, interpolatedFilter: interpolatedFilter)
            //NOTE: filter activities to avoid: `Fatal error: Duplicate values for key: '<id>'`
            let filteredActivities = activities.filter { data in !activitiesAndTokens.contains(where: { $0.activity.id == data.activity.id }) }
            activitiesAndTokens.append(contentsOf: filteredActivities)
        }

        return Self.filter(activities: activitiesAndTokens, strategy: activitiesFilterStrategy)
    }

    private static func filter(activities filteredActivitiesForThisCard: [ActivitiesService.ActivityTokenObjectTokenHolder], strategy: ActivitiesFilterStrategy) -> [ActivitiesService.ActivityTokenObjectTokenHolder] {
        switch strategy {
        case .none:
            return filteredActivitiesForThisCard
        case .contract(let contract), .operationTypes(_, let contract):
            return filteredActivitiesForThisCard.filter { mapped -> Bool in
                return mapped.tokenObject.contractAddress.sameContract(as: contract)
            }
        case .nativeCryptocurrency(let primaryKey):
            return filteredActivitiesForThisCard.filter { mapped -> Bool in
                return mapped.tokenObject.primaryKey == primaryKey
            }
        }
    }

    private func getActivities(forTokenContract contract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String) -> [ActivityTokenObjectTokenHolder] {
        //NOTE: eventsActivityDataStore. getRecentEvents() returns only 100 events, that could cause error with creating activities (missing events)
        //replace with fetching only filtered event instances,
        let events = eventsActivityDataStore.getRecentEventsSortedByBlockNumber(for: card.eventOrigin.contract, server: server, eventName: card.eventOrigin.eventName, interpolatedFilter: interpolatedFilter)

        let activitiesForThisCard: [ActivityTokenObjectTokenHolder] = events.compactMap { eachEvent in
            guard let token = tokensService.token(for: contract, server: server) else { return nil }

            let implicitAttributes = generateImplicitAttributesForToken(forContract: contract, server: server, symbol: token.symbol)
            let tokenAttributes = implicitAttributes
            var cardAttributes = Self.functional.generateImplicitAttributesForCard(forContract: contract, server: server, event: eachEvent)
            cardAttributes.merge(eachEvent.data) { _, new in new }

            for parameter in card.eventOrigin.parameters {
                guard let originalValue = cardAttributes[parameter.name] else { continue }
                guard let type = SolidityType(rawValue: parameter.type) else { continue }
                let translatedValue = type.coerce(value: originalValue)
                cardAttributes[parameter.name] = translatedValue
            }

            let tokenHolders: [TokenHolder]

            if let h = tokensAndTokenHolders[token.addressAndRPCServer] {
                tokenHolders = h
            } else {
                if token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                    let _token = TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: .init(1)), tokenType: .nativeCryptocurrency, index: 0, name: "", symbol: "", status: .available, values: .init())

                    tokenHolders = [TokenHolder(tokens: [_token], contractAddress: token.contractAddress, hasAssetDefinition: true)]
                } else {
                    tokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
                }
                tokensAndTokenHolders[token.addressAndRPCServer] = tokenHolders
            }
            //NOTE: using `tokenHolders[0]` i received crash with out of range exception
            guard let tokenHolder = tokenHolders.first else { return nil }
            //TODO fix for activities: special fix to filter out the event we don't want - need to doc this and have to handle with TokenScript design
            let isNativeCryptoAddress = token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase)
            if card.name == "aETHMinted" && isNativeCryptoAddress && cardAttributes["amount"]?.uintValue == 0 {
                return nil
            } else {
                //no-op
            }

            let activity = Activity(id: Int.random(in: 0..<Int.max), rowType: .standalone, token: token, server: eachEvent.server, name: card.name, eventName: eachEvent.eventName, blockNumber: eachEvent.blockNumber, transactionId: eachEvent.transactionId, transactionIndex: eachEvent.transactionIndex, logIndex: eachEvent.logIndex, date: eachEvent.date, values: (token: tokenAttributes, card: cardAttributes), view: card.view, itemView: card.itemView, isBaseCard: card.isBase, state: .completed)

            return (activity: activity, tokenObject: token, tokenHolder: tokenHolder)
        }

        return activitiesForThisCard
    }

    private func reloadViewController(reloadImmediately: Bool) {
        if reloadImmediately {
            combineActivitiesWithTransactions()
        } else {
            //We want to show the activities tab immediately the first time activities are available, otherwise when the app launch and user goes to the tab immediately and wait for a few seconds, they'll see some of the transactions transforming into activities. Very jarring
            if hasLoadedActivitiesTheFirstTime {
                if rateLimitedViewControllerReloader == nil {
                    rateLimitedViewControllerReloader = RateLimiter(name: "Reload activity/transactions in Activity tab", limit: 5, autoRun: true) { [weak self] in
                        self?.combineActivitiesWithTransactions()
                    }
                } else {
                    rateLimitedViewControllerReloader?.run()
                }
            } else {
                combineActivitiesWithTransactions()
            }
        }
    }

    public func reinject(activity: Activity) {
        guard let tokenHolders = tokensAndTokenHolders[activity.token.addressAndRPCServer] else { return }

        refreshActivity(token: activity.token, tokenHolder: tokenHolders[0], activity: activity, isFirstUpdate: true)
    }

    private func combineActivitiesWithTransactions() {
        if !activities.isEmpty {
            hasLoadedActivitiesTheFirstTime = true
        }

        let transactions = transactionDataStore.transactions(forFilter: transactionsFilterStrategy, servers: config.enabledServers, oldestBlockNumber: activities.array.last?.blockNumber)
        let items = combine(activities: activities.array, with: transactions)
        let activities = ActivityCollection.sorted(activities: items)

        activitiesSubject.send(activities)
    }

    //Combining includes filtering around activities (from events) for ERC20 send/receive transactions which are already covered by transactions
    private func combine(activities: [Activity], with transactions: [TransactionInstance]) -> [ActivityRowModel] {
        let all: [ActivityOrTransactionInstance] = activities.map { .activity($0) } + transactions.map { .transaction($0) }
        let sortedAll: [ActivityOrTransactionInstance] = all.sorted { $0.blockNumber < $1.blockNumber }
        let counters = Dictionary(grouping: sortedAll, by: \.blockNumber)

        return counters.map {
            generateRowModels(fromActivityOrTransactions: $0.value, withBlockNumber: $0.key)
        }.flatMap { $0 }
    }

    private func generateRowModels(fromActivityOrTransactions activityOrTransactions: [ActivityOrTransactionInstance], withBlockNumber blockNumber: Int) -> [ActivityRowModel] {
        if activityOrTransactions.isEmpty {
            //Shouldn't be possible
            return .init()
        } else if activityOrTransactions.count > 1 {
            let activities: [Activity] = activityOrTransactions.compactMap(\.activity)
            //TODO will we ever have more than 1 transaction object (not activity/event) in the database for the same block number? Maybe if we get 1 from normal Etherscan endpoint and another from Etherscan ERC20 history endpoint?
            if let transaction: TransactionInstance = activityOrTransactions.compactMap(\.transaction).first {
                var results: [ActivityRowModel] = .init()
                let activities: [Activity] = activities.filter { activity in
                    let operations = transaction.localizedOperations
                    return operations.allSatisfy { activity != $0 }
                }
                let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), service: tokensService, wallet: wallet.address)
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
                        let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), service: tokensService, wallet: wallet.address)
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
                let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), service: tokensService, wallet: wallet.address)
                if transaction.localizedOperations.isEmpty {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else if transaction.localizedOperations.count == 1 {
                    return [.standaloneTransaction(transaction: transaction, activity: activity)]
                } else {
                    let isSwap = self.isSwap(activities: activities.array, operations: transaction.localizedOperations, wallet: wallet)
                    var results: [ActivityRowModel] = .init()
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: .init()))
                    results.append(contentsOf: transaction.localizedOperations.map {
                        let activity = ActivityCollection.functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: $0), service: tokensService, wallet: wallet.address)

                        return .childTransaction(transaction: transaction, operation: $0, activity: activity)
                    })
                    return results
                }
            case .none:
                return .init()
            }
        }
    }

    private func isSwap(activities: [Activity], operations: [LocalizedOperationObjectInstance], wallet: Wallet) -> Bool {
        //Might have other transactions like approved embedded, so we can't check for all send and receives.
        let hasSend = activities.contains { $0.isSend } || operations.contains { $0.isSend(from: wallet.address) }
        let hasReceive = activities.contains { $0.isReceive } || operations.contains { $0.isReceived(by: wallet.address) }
        return hasSend && hasReceive
    }

    //Important to pass in the `TokenHolder` instance and not re-create so that we don't override the subscribable values for the token with ones that are not resolved yet
    private func refreshActivity(token: Token, tokenHolder: TokenHolder, activity: Activity, isFirstUpdate: Bool = true) {
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        let resolvedAttributeNameValues = attributeValues.resolve { [weak self, weak tokenHolder] _ in
            guard let tokenHolder = tokenHolder, isFirstUpdate else { return }
            self?.refreshActivity(token: token, tokenHolder: tokenHolder, activity: activity, isFirstUpdate: false)
        }

        //NOTE: Fix crush when element with index out of range
        if let (index, oldActivity) = activitiesIndexLookup[activity.id] {
            let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
            let updatedActivity: Activity = .init(id: oldActivity.id, rowType: oldActivity.rowType, token: token, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, transactionIndex: oldActivity.transactionIndex, logIndex: oldActivity.logIndex, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView, isBaseCard: oldActivity.isBaseCard, state: oldActivity.state)

            if activities.indices.contains(index) {
                activities[index] = updatedActivity
                reloadViewController(reloadImmediately: false)

                didUpdateActivitySubject.send(updatedActivity)
            }
        } else {
            //no-op. We should be able to find it unless the list of activities has changed
        }
    }

    private func generateImplicitAttributesForToken(forContract contract: AlphaWallet.Address, server: RPCServer, symbol: String) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            //TODO ERC721s aren't fungible, but doesn't matter here
            guard each.shouldInclude(forAddress: contract, isFungible: true) else { continue }
            switch each {
            case .ownerAddress:
                guard let session = sessions[safe: server] else { continue }
                results[each.javaScriptName] = .address(session.account.address)
            case .tokenId:
                //We aren't going to add `tokenId` as an implicit attribute even for ERC721s, because we don't know it
                break
            case .label:
                break
            case .symbol:
                results[each.javaScriptName] = .string(symbol)
            case .contractAddress:
                results[each.javaScriptName] = .address(contract)
            }
        }
        return results
    }

    //We can't run this in `activities` didSet {} because this will then be run unnecessarily, when we refresh each activity (we only want this to update when we refresh the entire activity list)
    private func updateActivitiesIndexLookup(with activities: [Activity]) {
        var arrayIndex = -1
        let newValue: [Int: (index: Int, activity: Activity)] = Dictionary(uniqueKeysWithValues: activities.map {
            arrayIndex += 1
            return ($0.id, (arrayIndex, $0))
        })
        activitiesIndexLookup.set(value: newValue)
    }
}

fileprivate func == (activity: Activity, operation: LocalizedOperationObjectInstance) -> Bool {
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

fileprivate func != (activity: Activity, operation: LocalizedOperationObjectInstance) -> Bool {
    !(activity == operation)
}

extension ActivitiesService {
    class functional {}
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
