// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: class {
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
    func show(tokenObject: TokenObject, fromCoordinator coordinator: ActivitiesCoordinator)
    func speedup(transactionWithId transactionId: String, forServer server: RPCServer, viewController: ActivityViewController, fromCoordinator coordinator: ActivitiesCoordinator)
    func cancel(transactionWithId transactionId: String, forServer server: RPCServer, viewController: ActivityViewController, fromCoordinator coordinator: ActivitiesCoordinator)
    func show(transactionWithId transactionId: String, server: RPCServer, inViewController viewController: UIViewController, fromCoordinator coordinator: ActivitiesCoordinator)
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, fromCoordinator coordinator: ActivitiesCoordinator, inViewController viewController: UIViewController)
}

// swiftlint:disable type_body_length
class ActivitiesCoordinator: Coordinator {
    private enum ActivityOrTransactionInstance {
        case activity(Activity)
        case transaction(TransactionInstance)

        var blockNumber: Int {
            switch self {
            case .activity(let activity):
                return activity.blockNumber
            case .transaction(let transaction):
                return transaction.blockNumber
            }
        }

        var transaction: TransactionInstance? {
            switch self {
            case .activity:
                return nil
            case .transaction(let transaction):
                return transaction
            }
        }
        var activity: Activity? {
            switch self {
            case .activity(let activity):
                return activity
            case .transaction:
                return nil
            }
        }
    }

    private let analyticsCoordinator: AnalyticsCoordinator
    private let config: Config
    private let keystore: Keystore
    private let sessions: ServerDictionary<WalletSession>
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    private let eventsDataStore: EventsDataStoreProtocol
    //Dictionary for lookup. Using `.firstIndex` too many times is too slow (60s for 10k events)
    private var activitiesIndexLookup: [Int: (index: Int, activity: Activity)] = .init()
    private var activities: [Activity] = .init()
    private var transactions: [TransactionInstance] = .init()

    private var tokensAndTokenHolders: [AlphaWallet.Address: (tokenObject: Activity.AssignedToken, tokenHolders: [TokenHolder])] = .init()
    weak private var activityViewController: ActivityViewController?
    private var rateLimitedUpdater: RateLimiter?
    private var rateLimitedViewControllerReloader: RateLimiter?
    private var hasLoadedActivitiesTheFirstTime = false
    private var lastActivitiesCount: Int = 0
    private var lastTransactionRowsCount: Int = 0
    private var lastTransactionBlockNumbers: [Int] = .init()

    weak var delegate: ActivitiesCoordinatorDelegate?

    private var tokensInDatabase: [TokenObject] {
        tokensStorages.values.flatMap { $0.enabledObject }
    }

    private var wallet: Wallet {
        sessions.anyValue.account
    }

    lazy var rootViewController: ActivitiesViewController = {
        functional.makeActivitiesViewController(tokensStorages: tokensStorages, sessions: sessions, coordinator: self, wallet: wallet)
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    //TODO need to restore and fix this speed up optimization again. Especially that it doesn't crash with a bigger wallet.
    //private let queue = DispatchQueue(label: "com.activities.updateQueue")
    private let queue = DispatchQueue.main
    //TODO this only exist because the previous is `main` for now
    private let queue2 = DispatchQueue(label: "com.activities.updateQueue")

    init(
        analyticsCoordinator: AnalyticsCoordinator,
        config: Config,
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = UINavigationController(),
        keystore: Keystore,
        tokensStorages: ServerDictionary<TokensDataStore>,
        assetDefinitionStore: AssetDefinitionStore,
        eventsActivityDataStore: EventsActivityDataStoreProtocol,
        eventsDataStore: EventsDataStoreProtocol,
        transactionCoordinator: TransactionCoordinator?
    ) {
        self.analyticsCoordinator = analyticsCoordinator
        self.config = config
        self.sessions = sessions
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.eventsActivityDataStore = eventsActivityDataStore
        transactionCoordinator?.dataCoordinator.delegate2 = self
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func showActivity(_ activity: Activity) {
        let controller = ActivityViewController(analyticsCoordinator: analyticsCoordinator, wallet: wallet, assetDefinitionStore: assetDefinitionStore, viewModel: .init(activity: activity))
        controller.delegate = self
        activityViewController = controller
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
    }

    func stop() {
        //TODO seems not good to stop here because others call stop too
        for each in sessions.values {
            each.stop()
        }
    }

    func reload() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Fetch activity from events in database", limit: 5, autoRun: true) { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.queue.async {
                    strongSelf.reloadImpl()
                }
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    func reloadImpl() {
        let contractServerXmlHandlers: [(contract: AlphaWallet.Address, server: RPCServer, xmlHandler: XMLHandler)] = tokensInDatabase.compactMap { each in
            let eachContract = each.contractAddress
            let eachServer = each.server
            let xmlHandler = XMLHandler(token: each, assetDefinitionStore: assetDefinitionStore)
            guard xmlHandler.hasAssetDefinition else { return nil }
            guard xmlHandler.server?.matches(server: eachServer) ?? false else { return nil }
            return (contract: eachContract, server: eachServer, xmlHandler: xmlHandler)
        }

        let contractsAndCardsOptional: [[(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]] = contractServerXmlHandlers.compactMap { eachContract, _, xmlHandler in
            var contractAndCard: [(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)] = .init()
            for card in xmlHandler.activityCards {
                let (filterName, filterValue) = card.eventOrigin.eventFilter
                let interpolatedFilter: String
                if let implicitAttribute = EventSourceCoordinatorForActivities.convertToImplicitAttribute(string: filterValue) {
                    switch implicitAttribute {
                    case .tokenId:
                        continue
                    case .ownerAddress:
                        interpolatedFilter = "\(filterName)=\(wallet.address.eip55String)"
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

        let contractsAndCards = contractsAndCardsOptional.flatMap { $0 }
        fetchAndRefreshActivities(contractsAndCards: contractsAndCards)
    }

    private func fetchAndRefreshActivities(contractsAndCards: [(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]) {
        let recentEvents = eventsActivityDataStore.getRecentEvents()
        var activitiesAndTokens: [(Activity, Activity.AssignedToken, TokenHolder)] = .init()
        for (eachContract, eachServer, card, interpolatedFilter) in contractsAndCards {
            let activities = getActivities(recentEvents, forTokenContract: eachContract, server: eachServer, card: card, interpolatedFilter: interpolatedFilter)
            activitiesAndTokens.append(contentsOf: activities)
        }

        activities = activitiesAndTokens.map { $0.0 }
        activities.sort { $0.blockNumber > $1.blockNumber }
        updateActivitiesIndexLookup()
        reloadViewController(reloadImmediately: false)

        for (activity, tokenObject, tokenHolder) in activitiesAndTokens {
            refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder, activity: activity)
        }
    }

    private func getActivities(_ allActivities: [EventActivity], forTokenContract contract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String) -> [(Activity, Activity.AssignedToken, TokenHolder)] {
        let events = allActivities.filter {
            $0.contract == card.eventOrigin.contract.eip55String
                    && $0.server == server
                    && $0.eventName == card.eventOrigin.eventName
                    && $0.filter == interpolatedFilter
        }

        //Cache tokens lookup for performance
        var tokensCache: [AlphaWallet.Address: Activity.AssignedToken] = .init()
        let activitiesForThisCard: [(activity: Activity, tokenObject: Activity.AssignedToken, tokenHolders: TokenHolder)] = events.compactMap { eachEvent in
            let token: Activity.AssignedToken
            if let t = tokensCache[contract] {
                token = t
            } else {
                let tokensDatastore = tokensStorages[server]
                guard let t = tokensDatastore.tokenThreadSafe(forContract: contract) else { return nil }
                let tt = Activity.AssignedToken(tokenObject: t)
                tokensCache[contract] = tt
                token = tt
            }

            let implicitAttributes = functional.generateImplicitAttributesForToken(forContract: contract, server: server, symbol: token.symbol, sessions: sessions)
            let tokenAttributes = implicitAttributes
            var cardAttributes = functional.generateImplicitAttributesForCard(forContract: contract, server: server, event: eachEvent)
            cardAttributes.merge(eachEvent.data) { _, new in new }

            for parameter in card.eventOrigin.parameters {
                guard let originalValue = cardAttributes[parameter.name] else { continue }
                guard let type = SolidityType(rawValue: parameter.type) else { continue }
                let translatedValue = type.coerce(value: originalValue)
                cardAttributes[parameter.name] = translatedValue
            }

            let tokenObject: Activity.AssignedToken
            let tokenHolders: [TokenHolder]
            if let (o, h) = tokensAndTokenHolders[contract] {
                tokenObject = o
                tokenHolders = h
            } else {
                tokenObject = token
                if tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                    let token = Token(tokenIdOrEvent: .tokenId(tokenId: .init(1)), tokenType: .nativeCryptocurrency, index: 0, name: "", symbol: "", status: .available, values: .init())

                    tokenHolders = [TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)]
                } else {
                    //NOTE: because this can be called from different threads we can use cache here, but we can cache Activity.AssignedToken
                    let tokensDatastore = tokensStorages[server]
                    guard let t = tokensDatastore.tokenThreadSafe(forContract: tokenObject.contractAddress) else { return nil }

                    tokenHolders = TokenAdaptor(token: t, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: sessions.anyValue.account)
                }
                tokensAndTokenHolders[contract] = (tokenObject: tokenObject, tokenHolders: tokenHolders)
            }

            let activity = Activity(id: Int.random(in: 0..<Int.max), rowType: .standalone, tokenObject: tokenObject, server: eachEvent.server, name: card.name, eventName: eachEvent.eventName, blockNumber: eachEvent.blockNumber, transactionId: eachEvent.transactionId, transactionIndex: eachEvent.transactionIndex, logIndex: eachEvent.logIndex, date: eachEvent.date, values: (token: tokenAttributes, card: cardAttributes), view: card.view, itemView: card.itemView, isBaseCard: card.isBase, state: .completed)

            //Check against crashing when ERC721 tokens sourced from OpenSea are empty (for some reason, maybe network, which should be fixed elsewhere any way)
            if let tokenHolder = tokenHolders.first {
                return (activity: activity, tokenObject: tokenObject, tokenHolders: tokenHolder)
            } else {
                return nil
            }
        }

        //TODO fix for activities: special fix to filter out the event we don't want - need to doc this and have to handle with TokenScript design
        let filteredActivitiesForThisCard = activitiesForThisCard.filter {
            if $0.activity.name == "aETHMinted" && $0.activity.tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) && $0.activity.values.card["amount"]?.uintValue == 0 {
                return false
            } else {
                return true
            }
        }

        return filteredActivitiesForThisCard
    }

    //TODO throttling reloading because sorting the activities for every attribute in every activity refreshed is really slow: can we speed this up?
    private func reloadViewController(reloadImmediately: Bool) {
        if reloadImmediately {
            reloadViewControllerImpl()
            return
        }

        //We want to show the activities tab immediately the first time activities are available, otherwise when the app launch and user goes to the tab immediately and wait for a few seconds, they'll see some of the transactions transforming into activities. Very jarring
        if hasLoadedActivitiesTheFirstTime {
            if rateLimitedViewControllerReloader == nil {
                rateLimitedViewControllerReloader = RateLimiter(name: "Reload activity/transactions in Activity tab", limit: 5, autoRun: true) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.queue.async {
                        strongSelf.reloadViewControllerImpl()
                    }
                }
            } else {
                rateLimitedViewControllerReloader?.run()
            }
        } else {
            reloadViewControllerImpl()
        }
    }

    private func reloadViewControllerImpl() {
        if !activities.isEmpty {
            hasLoadedActivitiesTheFirstTime = true
        }

        let transactions: [TransactionInstance]
        if activities.count == EventsActivityDataStore.numberOfActivitiesToUse, let blockNumberOfOldestActivity = activities.last?.blockNumber {
            transactions = self.transactions.filter { $0.blockNumber >= blockNumberOfOldestActivity }
        } else {
            transactions = self.transactions
        }

        let items = functional.combine(activities: activities, withTransactions: transactions)
        queue2.async {
            let activities = ActivitiesViewModel.sorted(activities: items)
            DispatchQueue.main.async {
                self.rootViewController.configure(viewModel: .init(tokensStorages: self.tokensStorages, activities: activities))
            }
        }
    }

    //Important to pass in the `TokenHolder` instance and not re-create so that we don't override the subscribable values for the token with ones that are not resolved yet
    private func refreshActivity(tokenObject: Activity.AssignedToken, tokenHolder: TokenHolder, activity: Activity, isFirstUpdate: Bool = true) {
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        let resolvedAttributeNameValues = attributeValues.resolve { [weak self, weak tokenHolder] _ in
            guard let strongSelf = self, let tokenHolder = tokenHolder, isFirstUpdate else { return }
            strongSelf.refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder, activity: activity, isFirstUpdate: false)
        }

        if let (index, oldActivity) = activitiesIndexLookup[activity.id] {
            let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
            let updatedActivity: Activity = .init(id: oldActivity.id, rowType: oldActivity.rowType, tokenObject: tokenObject, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, transactionIndex: oldActivity.transactionIndex, logIndex: oldActivity.logIndex, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView, isBaseCard: oldActivity.isBaseCard, state: oldActivity.state)

            activities[index] = updatedActivity
            reloadViewController(reloadImmediately: false)

            if let activityViewController = activityViewController, activityViewController.isForActivity(updatedActivity) {
                activityViewController.configure(viewModel: .init(activity: updatedActivity))
            }
        } else {
            //no-op. We should be able to find it unless the list of activities has changed
        }
    }

    //We can't run this in `activities` didSet {} because this will then be run unnecessarily, when we refresh each activity (we only want this to update when we refresh the entire activity list)
    private func updateActivitiesIndexLookup() {
        var arrayIndex = -1
        activitiesIndexLookup = Dictionary(uniqueKeysWithValues: activities.map {
            arrayIndex += 1
            return ($0.id, (arrayIndex, $0))
        })
    }
}
// swiftlint:enable type_body_length

extension ActivitiesCoordinator: ActivitiesViewControllerDelegate {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        showActivity(activity)
    }

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}

extension ActivitiesCoordinator: ActivityViewControllerDelegate {
    func reinject(viewController: ActivityViewController) {
        guard let (token, tokenHolder) = tokensAndTokenHolders[viewController.viewModel.activity.tokenObject.contractAddress] else { return }
        let activity = viewController.viewModel.activity

        refreshActivity(tokenObject: token, tokenHolder: tokenHolder[0], activity: activity)
    }

    func goToToken(viewController: ActivityViewController) {
        let token = viewController.viewModel.activity.tokenObject
        guard let tokenObject = tokensStorages[token.server].token(forContract: token.contractAddress) else { return }

        delegate?.show(tokenObject: tokenObject, fromCoordinator: self)
    }

    func speedupTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        delegate?.speedup(transactionWithId: transactionId, forServer: server, viewController: viewController, fromCoordinator: self)
    }

    func cancelTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        delegate?.cancel(transactionWithId: transactionId, forServer: server, viewController: viewController, fromCoordinator: self)
    }

    func goToTransaction(viewController: ActivityViewController) {
        delegate?.show(transactionWithId: viewController.viewModel.activity.transactionId, server: viewController.viewModel.activity.server, inViewController: viewController, fromCoordinator: self)
    }

    func didPressViewContractWebPage(_ contract: AlphaWallet.Address, server: RPCServer, viewController: ActivityViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, fromCoordinator: self, inViewController: viewController)
    }
}

extension ActivitiesCoordinator: TransactionDataCoordinatorDelegate {
    func didUpdate(result: ResultResult<[TransactionInstance], TransactionError>.t, reloadImmediately: Bool) {
        switch result {
        case .success(let items):
            transactions = items
            reloadViewController(reloadImmediately: reloadImmediately)
        case .failure:
            break
        }
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
        case .erc20TokenApprove:
            return activity.nativeViewType == .erc20OwnerApproved || activity.nativeViewType == .erc20ApprovalObtained || activity.nativeViewType == .erc721OwnerApproved || activity.nativeViewType == .erc721ApprovalObtained
        case .erc721TokenTransfer:
            return (activity.nativeViewType == .erc721Sent || activity.nativeViewType == .erc721Received) && isSameAmount() && isSameFrom() && isSameTo()
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

extension ActivitiesCoordinator {
    class functional {}
}

extension ActivitiesCoordinator.functional {
    static func makeActivitiesViewController(tokensStorages: ServerDictionary<TokensDataStore>, sessions: ServerDictionary<WalletSession>, coordinator: ActivitiesCoordinator, wallet: Wallet) -> ActivitiesViewController {
        let viewModel = ActivitiesViewModel(tokensStorages: tokensStorages)
        let controller = ActivitiesViewController(viewModel: viewModel, wallet: wallet.address, sessions: sessions, tokensStorages: tokensStorages)
        controller.delegate = coordinator
        return controller
    }

    //Combining includes filtering around activities (from events) for ERC20 send/receive transactions which are already covered by transactions
    static func combine(activities: [Activity], withTransactions transactionInstances: [TransactionInstance]) -> [ActivityRowModel] {
        let all: [ActivitiesCoordinator.ActivityOrTransactionInstance] = activities.map { .activity($0) } + transactionInstances.map { .transaction($0) }
        let sortedAll: [ActivitiesCoordinator.ActivityOrTransactionInstance] = all.sorted { $0.blockNumber < $1.blockNumber }
        var results: [ActivityRowModel] = .init()
        let counters = Dictionary(grouping: sortedAll, by: \.blockNumber)
        for (blockNumber, elements) in counters {
            let rows = generateRowModels(fromActivityOrTransactions: elements, withBlockNumber: blockNumber)
            results.append(contentsOf: rows)
        }
        return results
    }

    static private func generateRowModels(fromActivityOrTransactions activityOrTransactions: [ActivitiesCoordinator.ActivityOrTransactionInstance], withBlockNumber blockNumber: Int) -> [ActivityRowModel] {
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

                if transaction.localizedOperations.isEmpty && activities.isEmpty {
                    results.append(.standaloneTransaction(transaction: transaction))
                } else if transaction.localizedOperations.count == 1, transaction.value == "0", activities.isEmpty {
                    results.append(.standaloneTransaction(transaction: transaction))
                } else if transaction.localizedOperations.isEmpty && activities.count == 1 {
                    results.append(.parentTransaction(transaction: transaction, isSwap: false, activities: activities))
                    results.append(contentsOf: activities.map { .childActivity(transaction: transaction, activity: $0) })
                } else {
                    let isSwap = self.isSwap()
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: activities))
                    results.append(contentsOf: transaction.localizedOperations.map { .childTransaction(transaction: transaction, operation: $0) })
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
                if transaction.localizedOperations.isEmpty {
                    return [.standaloneTransaction(transaction: transaction)]
                } else if transaction.localizedOperations.count == 1 {
                    return [.standaloneTransaction(transaction: transaction)]
                } else {
                    let isSwap = self.isSwap()
                    var results: [ActivityRowModel] = .init()
                    results.append(.parentTransaction(transaction: transaction, isSwap: isSwap, activities: .init()))
                    results.append(contentsOf: transaction.localizedOperations.map { .childTransaction(transaction: transaction, operation: $0) })
                    return results
                }
            case .none:
                return .init()
            }
        }
    }

    //TODO need arguments
    //TODO implement better heuristics for swap, possibly building and comparing against a known list of contracts usedw by DEXs?
    static func isSwap() -> Bool {
        return false
    }

    static func generateImplicitAttributesForToken(forContract contract: AlphaWallet.Address, server: RPCServer, symbol: String, sessions: ServerDictionary<WalletSession>) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            //TODO ERC721s aren't fungible, but doesn't matter here
            guard each.shouldInclude(forAddress: contract, isFungible: true) else { continue }
            switch each {
            case .ownerAddress:
                results[each.javaScriptName] = .address(sessions[server].account.address)
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

    static func generateImplicitAttributesForCard(forContract contract: AlphaWallet.Address, server: RPCServer, event: EventActivity) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        var timestamp: GeneralisedTime = .init()
        timestamp.date = event.date
        results["timestamp"] = .generalisedTime(timestamp)
        return results
    }
}