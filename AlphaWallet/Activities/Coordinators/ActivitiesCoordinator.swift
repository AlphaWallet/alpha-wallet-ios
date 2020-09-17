// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: class {
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
    func show(tokenObject: TokenObject, fromCoordinator coordinator: ActivitiesCoordinator)
}

class ActivitiesCoordinator: Coordinator {
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
    private var transactions: [Transaction] = .init()
    private var tokensAndTokenHolders: [AlphaWallet.Address: (tokenObject: TokenObject, tokenHolders: [TokenHolder])] = .init()
    weak private var activityViewController:  ActivityViewController?
    private var rateLimitedUpdater: RateLimiter?
    private var rateLimitedViewControllerReloader: RateLimiter?
    private var hasLoadedActivitiesTheFirstTime = false

    weak var delegate: ActivitiesCoordinatorDelegate?

    private var tokensInDatabase: [TokenObject] {
        tokensStorages.values.flatMap { $0.enabledObject }
    }

    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        config: Config,
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        tokensStorages: ServerDictionary<TokensDataStore>,
        assetDefinitionStore: AssetDefinitionStore,
        eventsActivityDataStore: EventsActivityDataStoreProtocol,
        eventsDataStore: EventsDataStoreProtocol,
        transactionCoordinator: TransactionCoordinator?
    ) {
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
        let viewModel = ActivitiesViewModel()
        let controller = ActivitiesViewController(viewModel: viewModel, sessions: sessions)
        controller.delegate = self
        return controller
    }

    func showActivity(_ activity: Activity) {
        let controller = ActivityViewController(assetDefinitionStore: assetDefinitionStore, viewModel: .init(activity: activity))
        controller.delegate = self
        activityViewController = controller
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .formSheet
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            nav.makePresentationFullScreenForiOS13Migration()
            navigationController.present(nav, animated: true, completion: nil)
        } else {
            controller.hidesBottomBarWhenPushed = true
            controller.navigationItem.largeTitleDisplayMode = .never
            navigationController.pushViewController(controller, animated: true)
        }
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
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
                self?.reloadImpl()
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
            guard (xmlHandler.server?.matches(server: eachServer) ?? false) else { return nil }
            return (contract: eachContract, server: eachServer, xmlHandler: xmlHandler)
        }

        let contractsAndCardsOptional: [[(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)]] = contractServerXmlHandlers.flatMap { eachContract, eachServer, xmlHandler in
            var contractAndCard: [(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String)] = .init()
            for card in xmlHandler.activityCards {
                let (filterName, filterValue) = card.eventOrigin.eventFilter
                let interpolatedFilter: String
                if let implicitAttribute = EventSourceCoordinatorForActivities.convertToImplicitAttribute(string: filterValue) {
                    switch implicitAttribute {
                    case .tokenId:
                        continue
                    case .ownerAddress:
                        let wallet = sessions.anyValue.account.address
                        interpolatedFilter = "\(filterName)=\(wallet.eip55String)"
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
        var activitiesAndTokens: [(Activity, TokenObject, TokenHolder)] = .init()
        for (eachContract, eachServer, card, interpolatedFilter) in contractsAndCards {
            let activities = getActivities(forTokenContract: eachContract, server: eachServer, card: card, interpolatedFilter: interpolatedFilter)
            activitiesAndTokens.append(contentsOf: activities)
        }

        activities = activitiesAndTokens.map { $0.0 }
        activities.sort { $0.blockNumber > $1.blockNumber }
        updateActivitiesIndexLookup()
        reloadViewController()
        for (activity, tokenObject, tokenHolder) in activitiesAndTokens {
            refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder, activity: activity)
        }
    }

    private func getActivities(forTokenContract contract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, interpolatedFilter: String) -> [(Activity, TokenObject, TokenHolder)] {
        let events = eventsActivityDataStore.getEvents(forContract: card.eventOrigin.contract, forEventName: card.eventOrigin.eventName, filter: interpolatedFilter, server: server)
        //Cache tokens lookup for performance
        var tokensCache: [AlphaWallet.Address: TokenObject] = .init()
        let activitiesForThisCard: [(activity: Activity, tokenObject: TokenObject, tokenHolder: TokenHolder)] = events.compactMap { eachEvent in
            let token: TokenObject
            if let t = tokensCache[contract] {
                token = t
            } else {
                let tokensDatastore = tokensStorages[server]
                guard let t = tokensDatastore.token(forContract: contract) else { return nil }
                tokensCache[contract] = t
                token = t
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
            let tokenObject: TokenObject
            let tokenHolders: [TokenHolder]
            if let (o, h) = tokensAndTokenHolders[contract] {
                tokenObject = o
                tokenHolders = h
            } else {
                tokenObject = token
                if tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                    tokenHolders = [TokenHolder(tokens: [Token(tokenIdOrEvent: .tokenId(tokenId: .init(1)), tokenType: .nativeCryptocurrency, index: 0, name: "", symbol: "", status: .available, values: .init())], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)]
                } else {
                    tokenHolders = TokenAdaptor(token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: sessions.anyValue.account)
                }
                tokensAndTokenHolders[contract] = (tokenObject: tokenObject, tokenHolders: tokenHolders)
            }
            return (activity: .init(id: Int.random(in: 0..<Int.max), tokenObject: tokenObject, server: eachEvent.server, name: card.name, eventName: eachEvent.eventName, blockNumber: eachEvent.blockNumber, transactionId: eachEvent.transactionId, date: eachEvent.date, values: (token: tokenAttributes, card: cardAttributes), view: card.view, itemView: card.itemView, isBaseCard: card.isBase), tokenObject: tokenObject, tokenHolder: tokenHolders[0])
        }

        //TODO fix for activities: special fix to filter out the event we don't want - need to doc this and have to handle with TokenScript design
        let filteredActivitiesForThisCard = activitiesForThisCard.filter {
            if $0.activity.name == "aETHMinted" && $0.activity.tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) && $0.activity.values.card["amount"]?.uintValue == .init() {
                return false
            } else {
                return true
            }
        }

        return filteredActivitiesForThisCard
    }

    //TODO throttling reloading because sorting the activities for every attribute in every activity refreshed is really slow: can we speed this up?
    private func reloadViewController() {
        //We want to show the activities tab immediately the first time activities are available, otherwise when the app launch and user goes to the tab immediately and wait for a few seconds, they'll see some of the transactions transforming into activities. Very jarring
        if hasLoadedActivitiesTheFirstTime {
            if rateLimitedViewControllerReloader == nil {
                rateLimitedViewControllerReloader = RateLimiter(name: "Reload activity/transactions in Activity tab", limit: 5, autoRun: true) { [weak self] in
                    self?.reloadViewControllerImpl()
                }
            } else {
                rateLimitedViewControllerReloader?.run()
            }
        } else {
            if !activities.isEmpty {
                hasLoadedActivitiesTheFirstTime = true
            }
            reloadViewControllerImpl()
        }
    }

    private func reloadViewControllerImpl() {
        let transactionAlreadyRepresentedAsActivities = Set(activities.map { $0.transactionId })
        let items: [ActivityOrTransaction] = activities.map { .activity($0) } + transactions.filter { txn in !transactionAlreadyRepresentedAsActivities.contains(txn.id) }.map { .transaction($0) }
        rootViewController.configure(viewModel: .init(activities: items))
    }

    //Important to pass in the `TokenHolder` instance and not re-create so that we don't override the subscribable values for the token with ones that are not resolved yet
    private func refreshActivity(tokenObject: TokenObject, tokenHolder: TokenHolder, activity: Activity, isFirstUpdate: Bool = true) {
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        let resolvedAttributeNameValues = attributeValues.resolve { [weak self] values in
            guard let strongSelf = self else { return }
            guard isFirstUpdate else { return }
            strongSelf.refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder, activity: activity, isFirstUpdate: false)
        }
        if let (index, oldActivity) = activitiesIndexLookup[activity.id] {
            let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
            let updatedActivity: Activity = .init(id: oldActivity.id, tokenObject: tokenObject, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView, isBaseCard: oldActivity.isBaseCard)
            activities[index] = updatedActivity
            reloadViewController()
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

    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}

extension ActivitiesCoordinator: ActivityViewControllerDelegate {
    func reinject(viewController: ActivityViewController) {
        guard let (tokenObject, tokenHolder) = tokensAndTokenHolders[viewController.viewModel.activity.tokenObject.contractAddress] else { return }
        let activity = viewController.viewModel.activity
        refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder[0], activity: activity)
    }

    func goToToken(viewController: ActivityViewController) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            viewController.dismiss(animated: false)
        } else {
            navigationController.popViewController(animated: false)
        }
        delegate?.show(tokenObject: viewController.viewModel.activity.tokenObject, fromCoordinator: self)
    }
}

extension ActivitiesCoordinator: TransactionDataCoordinatorDelegate {
    func didUpdate(result: ResultResult<[Transaction], TransactionError>.t) {
        switch result {
        case .success(let items):
            transactions = items
            reloadViewController()
        case .failure(let error):
            break
        }
    }
}
