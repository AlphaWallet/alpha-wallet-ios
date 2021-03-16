// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: class {
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
    func show(tokenObject: TokenObject, fromCoordinator coordinator: ActivitiesCoordinator)
    func show(transactionWithId transactionId: String, server: RPCServer, inViewController viewController: UIViewController, fromCoordinator coordinator: ActivitiesCoordinator)
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, fromCoordinator coordinator: ActivitiesCoordinator, inViewController viewController: UIViewController)
}

class ActivitiesCoordinator: Coordinator {
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
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    private let queue = DispatchQueue(label: "com.activities.updateQueue")

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

    private func makeActivitiesViewController() -> ActivitiesViewController {
        let viewModel = ActivitiesViewModel(tokensStorages: tokensStorages)
        let controller = ActivitiesViewController(viewModel: viewModel, wallet: wallet.address, sessions: sessions, tokensStorages: tokensStorages)
        controller.delegate = self

        return controller
    }

    func showActivity(_ activity: Activity) {
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

            let implicitAttributes = generateImplicitAttributesForToken(forContract: contract, server: server, symbol: token.symbol)
            let tokenAttributes = implicitAttributes
            var cardAttributes = generateImplicitAttributesForCard(forContract: contract, server: server, event: eachEvent)
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

            return (activity: activity, tokenObject: tokenObject, tokenHolders: tokenHolders[0])
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

        let items = combine(activities: activities, withTransactions: transactions)

        if let items = items {
            let activities = ActivitiesViewModel.sorted(activities: items)

            DispatchQueue.main.async {
                self.rootViewController.configure(viewModel: .init(tokensStorages: self.tokensStorages, activities: activities))
            }
        }
    }

    //Combining includes filtering around activities (from events) for ERC20 send/receive transctions which are already covered by transactions
    private func combine(activities: [Activity], withTransactions transactionInstances: [TransactionInstance]) -> [ActivityOrTransactionRow]? {
        var transactionRows: [TransactionRow] = .init()
        for each in transactions {
            if each.localizedOperations.isEmpty {
                transactionRows.append(.standalone(each))
            } else if each.localizedOperations.count == 1, each.value == "0" {
                transactionRows.append(.standalone(each))
            } else {
                transactionRows.append(.group(each))
                transactionRows.append(contentsOf: each.localizedOperations.map { .item(transaction: each, operation: $0) })
            }
        }
        let maximumNumberOfPendingTransactionsAtTheSameTime = 5
        let transactionBlockNumbers = transactionInstances[0..<min(transactionInstances.count, maximumNumberOfPendingTransactionsAtTheSameTime)].map(\.blockNumber)
        //Combining is an expensive operation which blocks the main thread. We avoid it if there are no new data
        if lastActivitiesCount == activities.count && lastTransactionRowsCount == transactionRows.count && transactionBlockNumbers == lastTransactionBlockNumbers { return nil }

        lastActivitiesCount = activities.count
        lastTransactionRowsCount = transactionRows.count
        lastTransactionBlockNumbers = transactionBlockNumbers
        var items: [ActivityOrTransactionRow] = .init()
        //We maintain the index to start looking in the array of `TransactionRow`s. Otherwise, the nested for-loops is very costly performance wise. This assumes activities and transactions are sorted by blockNumber in the same (descending) order
        var transactionRowsIndex = 0
        for each in activities {
            var erc20TransactionsInSameBlock: [TransactionRow] = .init()
            for rowIndex in transactionRowsIndex..<transactionRows.count {
                let transactionRow = transactionRows[rowIndex]
                guard transactionRow.blockNumber == each.blockNumber, transactionRow.operation?.operationType == .erc20TokenTransfer, transactionRow.operation?.value != nil else {
                    transactionRowsIndex = rowIndex + 1
                    break
                }
                guard transactionRow.operation?.value == each.values.card["amount"]?.uintValue.flatMap({ String($0) }) else { continue }
                erc20TransactionsInSameBlock.append(transactionRow)
            }

            switch each.nativeViewType {
            case .erc20Sent:
                if erc20TransactionsInSameBlock.contains(where: { (transactionRow: TransactionRow) in
                    let from: String? = transactionRow.operation?.from
                    let sameSender: Bool = (each.values.card["from"]?.addressValue.flatMap { wallet.address.sameContract(as: $0) } ?? false) && (from.flatMap { each.values.card["from"]?.addressValue?.sameContract(as: $0) } ?? false)
                    return sameSender
                }) {
                    //no-op
                } else {
                    items.append(.activity(each))
                }
            case .erc20Received:
                if erc20TransactionsInSameBlock.contains(where: { (transactionRow: TransactionRow) in
                    let to: String? = transactionRow.operation?.to
                    let sameRecipient: Bool = (each.values.card["to"]?.addressValue.flatMap { wallet.address.sameContract(as: $0) } ?? false) && (to.flatMap { each.values.card["to"]?.addressValue?.sameContract(as: $0) } ?? false)
                    return sameRecipient
                }) {
                    //no-op
                } else {
                    items.append(.activity(each))
                }
            case .erc20OwnerApproved, .erc20ApprovalObtained, .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained, .none, .nativeCryptoSent, .nativeCryptoReceived:
                items.append(.activity(each))
            }
        }
        items += transactionRows.map { .transactionRow($0) }
        return items
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

    private func generateImplicitAttributesForToken(forContract contract: AlphaWallet.Address, server: RPCServer, symbol: String) -> [String: AssetInternalValue] {
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

    private func generateImplicitAttributesForCard(forContract contract: AlphaWallet.Address, server: RPCServer, event: EventActivity) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        var timestamp: GeneralisedTime = .init()
        timestamp.date = event.date
        results["timestamp"] = .generalisedTime(timestamp)
        return results
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
