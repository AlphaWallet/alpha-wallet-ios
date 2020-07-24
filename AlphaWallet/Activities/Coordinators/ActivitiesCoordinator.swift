// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: class {
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
}

class ActivitiesCoordinator: Coordinator {
    private let keystore: Keystore
    private let sessions: ServerDictionary<WalletSession>
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    private let eventsDataStore: EventsDataStoreProtocol
    private var activities: [Activity] = .init()
    private var transactions: [Transaction] = .init()
    private var tokensAndTokenHolders: [AlphaWallet.Address: (tokenObject: TokenObject, tokenHolders: [TokenHolder])] = .init()
    weak private var activityViewController:  ActivityViewController?

    weak var delegate: ActivitiesCoordinatorDelegate?

    private var contractsAndServerInDatabase: [(AlphaWallet.Address, RPCServer)] {
        var contractsAndServers = [(AlphaWallet.Address, RPCServer)]()
        for each in tokensStorages.values {
            contractsAndServers.append(contentsOf: each.enabledObject.map { ($0.contractAddress, $0.server) })
        }
        return contractsAndServers
    }

    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        tokensStorages: ServerDictionary<TokensDataStore>,
        assetDefinitionStore: AssetDefinitionStore,
        eventsActivityDataStore: EventsActivityDataStoreProtocol,
        eventsDataStore: EventsDataStoreProtocol,
        transactionCoordinator: TransactionCoordinator?
    ) {
        self.sessions = sessions
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.eventsActivityDataStore = eventsActivityDataStore
        //TODO fix for activities: remove to support transactions appearing in Activity tab properly
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
        var activitiesAndTokens: [(Activity, TokenObject, TokenHolder)] = .init()
        for (eachContract, eachServer) in contractsAndServerInDatabase {
            let xmlHandler = XMLHandler(contract: eachContract, assetDefinitionStore: assetDefinitionStore)
            guard xmlHandler.hasAssetDefinition else { continue }
            guard xmlHandler.server == eachServer else { continue }
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
                let events = eventsActivityDataStore.getEvents(forEventName: card.eventOrigin.eventName, filter: interpolatedFilter, server: server)
                let activitiesForThisCard: [(activity: Activity, tokenObject: TokenObject, tokenHolder: TokenHolder)] = events.compactMap { eachEvent in
                    let implicitAttributes = generateImplicitAttributesForToken(forContract: eachEvent.tokenContractAddress, server: server)
                    let tokenAttributes = implicitAttributes
                    var cardAttributes = generateImplicitAttributesForCard(forContract: eachEvent.tokenContractAddress, server: server, event: eachEvent)
                    cardAttributes.merge(eachEvent.data) { _, new in new }
                    for parameter in card.eventOrigin.parameters {
                        guard let originalValue = cardAttributes[parameter.name] else { continue }
                        guard let type = SolidityType(rawValue: parameter.type) else { continue }
                        let translatedValue = type.coerce(value: originalValue)
                        cardAttributes[parameter.name] = translatedValue
                    }
                    let tokenObject: TokenObject
                    let tokenHolders: [TokenHolder]
                    if let (o, h) = tokensAndTokenHolders[eachContract] {
                        tokenObject = o
                        tokenHolders = h
                    } else {
                        let tokensDatastore = tokensStorages[server]
                        guard let token = tokensDatastore.token(forContract: eachContract) else { return nil }
                        tokenObject = token
                        if tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                            //TODO fix for activities: good? Also hardcoded tokenID = 1
                            tokenHolders = [TokenHolder(tokens: [Token(tokenIdOrEvent: .tokenId(tokenId: .init(1)), tokenType: .nativeCryptocurrency, index: 0, name: "", symbol: "", status: .available, values: .init())], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)]
                        } else {
                            tokenHolders = TokenAdaptor(token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: sessions.anyValue.account)
                        }


                        tokensAndTokenHolders[eachContract] = (tokenObject: tokenObject, tokenHolders: tokenHolders)
                    }
                    //TODO support ERC721 for activities: have to be careful for ERC721, there are more than one TokenHolder. Skip for demo?
                    return (activity: .init(id: Int.random(in: 0..<Int.max), tokenObject: tokenObject, server: eachEvent.server, name: card.name, eventName: eachEvent.eventName, blockNumber: eachEvent.blockNumber, transactionId: eachEvent.transactionId, date: eachEvent.date, values: (token: tokenAttributes, card: cardAttributes), view: card.view, itemView: card.itemView), tokenObject: tokenObject, tokenHolder: tokenHolders[0])
                }

                //TODO fix for activities: special fix to filter out the event we don't want
                let filteredActivitiesForThisCard = activitiesForThisCard.filter {
                    if $0.activity.name == "aETHMinted" && $0.activity.tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) && $0.activity.values.card["amount"]?.uintValue == .init() {
                        return false
                    } else {
                        return true
                    }
                }
                activitiesAndTokens.append(contentsOf: filteredActivitiesForThisCard)
            }
        }
        activities = activitiesAndTokens.map { $0.0 }
        activities.sort { $0.blockNumber > $1.blockNumber }
        reloadViewController()

        for (activity, tokenObject, tokenHolder) in activitiesAndTokens {
            refreshActivity(tokenObject: tokenObject, tokenHolder: tokenHolder, activity: activity)
        }
    }

    private func reloadViewController() {
        let transactionAlreadyRepresentedAsActivities = activities.map { $0.transactionId }
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
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            let oldActivity = activities[index]
            let updatedValues = (token: oldActivity.values.token.merging(resolvedAttributeNameValues) { _, new in new }, card: oldActivity.values.card)
            let updatedActivity: Activity = .init(id: oldActivity.id, tokenObject: tokenObject, server: oldActivity.server, name: oldActivity.name, eventName: oldActivity.eventName, blockNumber: oldActivity.blockNumber, transactionId: oldActivity.transactionId, date: oldActivity.date, values: updatedValues, view: oldActivity.view, itemView: oldActivity.itemView)
            activities[index] = updatedActivity
            reloadViewController()
            if let activityViewController = activityViewController, activityViewController.isForActivity(updatedActivity) {
                activityViewController.configure(viewModel: .init(activity: updatedActivity))
            }
        } else {
            //no-op. We should be able to find it unless the list of activities has changed
        }
    }

    private func generateImplicitAttributesForToken(forContract contract: AlphaWallet.Address, server: RPCServer) -> [String: AssetInternalValue] {
        let tokensDatastore = tokensStorages[server]
        let symbol: String
        if let existingToken = tokensDatastore.token(forContract: contract) {
            symbol = existingToken.symbol
        } else {
            symbol = ""
        }

        //TODO support ERC721 for activities: hardcoded. ERC20 now. But we do ERC721 too
        let isFungible = true
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            guard each.shouldInclude(forAddress: contract, isFungible: isFungible) else { continue }
            switch each {
            case .ownerAddress:
                results[each.javaScriptName] = .address(sessions[server].account.address)
            case .tokenId:
                //TODO support ERC721 for activities: hardcoded. ERC20 now. But we do ERC721 too
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
        //TODO fix for activities: have to formalise this so it's in TokenScript design and so Android does it too. And remove the magic string
        var results = [String: AssetInternalValue]()
        var timestamp: GeneralisedTime = .init()
        timestamp.date = event.date
        results["timestamp"] = .generalisedTime(timestamp)
        return results
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
