// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import BigInt
import Combine
import AlphaWalletWeb3

final class EventSourceForActivities {
    private let config: Config
    private let tokensService: TokenProvidable
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.EventSourceForActivities.updateQueue")
    private let enabledServers: [RPCServer]
    private var cancellable = Set<AnyCancellable>()
    private let fetcher: EventForActivitiesFetcher

    init(wallet: Wallet,
         config: Config,
         tokensService: TokenProvidable,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: EventsActivityDataStoreProtocol,
         sessionsProvider: SessionsProvider) {

        self.config = config
        self.tokensService = tokensService
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.enabledServers = config.enabledServers
        self.fetcher = EventForActivitiesFetcher(sessionsProvider: sessionsProvider)
    }

    func start() {
        guard !config.development.isAutoFetchingDisabled else { return }

        subscribeForTokenChanges()
        subscribeForTokenScriptFileChanges()
    }

    private func subscribeForTokenChanges() {
        tokensService.tokensPublisher(servers: enabledServers)
            .receive(on: queue)
            .sink { [weak self] _ in self?.fetchAllEvents() }
            .store(in: &cancellable)
    }

    private func subscribeForTokenScriptFileChanges() {
        assetDefinitionStore.bodyChange
            .receive(on: queue)
            .compactMap { [tokensService] in tokensService.token(for: $0) }
            .sink { [weak self] in self?.fetchAllEvents(for: $0) }
            .store(in: &cancellable)
    }

    private func fetchAllEvents(for token: Token) {
        for each in fetchMappedContractsAndServers(token: token) {
            guard let token = tokensService.token(for: each.contract, server: each.server) else { return }
            fetchEvents(for: token)
                .sink { _ in }
                .store(in: &cancellable)
        }
    }

    private func fetchMappedContractsAndServers(token: Token) -> [(contract: AlphaWallet.Address, server: RPCServer)] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return [] }
        switch server {
        case .any:
            return enabledServers.map { (contract: token.contractAddress, server: $0) }
        case .server(let server):
            return [(contract: token.contractAddress, server: server)]
        }
    }

    private func getActivityCards(forToken token: Token) -> [TokenScriptCard] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards
    }

    private func fetchEvents(for token: Token) -> AnyPublisher<[EventActivityInstance], Never> {
        let publishers = getActivityCards(forToken: token)
            .map { card -> AnyPublisher<[EventActivityInstance], Never> in
                let eventOrigin = card.eventOrigin
                let oldEvent = eventsDataStore.getLastMatchingEventSortedByBlockNumber(
                    for: eventOrigin.contract,
                    tokenContract: token.contractAddress,
                    server: token.server,
                    eventName: eventOrigin.eventName)

                return fetcher.fetchEvents(token: token, card: card, oldEventBlockNumber: oldEvent?.blockNumber)
                    .handleEvents(receiveOutput: { [eventsDataStore] in eventsDataStore.addOrUpdate(events: $0) })
                    .replaceError(with: [])
                    .eraseToAnyPublisher()
            }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { $0.flatMap { $0 } }
            .eraseToAnyPublisher()
    }

    private func fetchAllEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for Activities", limit: 60, autoRun: true) { [weak self] in
                self?.queue.async {
                    self?.fetchAllEventsImpl()
                }
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func fetchAllEventsImpl() {
        guard !isFetching else { return }
        isFetching = true

        let publishers = tokensService.tokens(for: enabledServers).map { fetchEvents(for: $0) }.flatMap { $0 }

        Publishers.MergeMany(publishers)
            .collect()
            .sink { [weak self] _ in self?.isFetching = false }
            .store(in: &cancellable)
    }
}

extension EventSourceForActivities {
    class functional {}
}

extension EventSourceForActivities.functional {
    static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, tokenContract: AlphaWallet.Address, server: RPCServer) -> EventActivityInstance? {
        guard let eventLog = event.eventLog else { return nil }

        let transactionId = eventLog.transactionHash.hexEncoded
        let decodedResult = EventSource.functional.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventActivityInstance(
            contract: eventOrigin.contract,
            tokenContract: tokenContract,
            server: server,
            date: date,
            eventName: eventOrigin.eventName,
            blockNumber: Int(eventLog.blockNumber),
            transactionId: transactionId,
            transactionIndex: Int(eventLog.transactionIndex),
            logIndex: Int(eventLog.logIndex),
            filter: filterText,
            json: json)
    }

    static func formFilterFrom(fromParameter parameter: EventParameter, filterName: String, filterValue: String, wallet: Wallet) -> (filter: [EventFilterable], textEquivalent: String)? {
        guard parameter.name == filterName else { return nil }
        guard let parameterType = SolidityType(rawValue: parameter.type) else { return nil }
        let optionalFilter: (filter: AssetAttributeValueUsableAsFunctionArguments, textEquivalent: String)?
        if let implicitAttribute = EventSource.functional.convertToImplicitAttribute(string: filterValue) {
            switch implicitAttribute {
            case .tokenId:
                optionalFilter = nil
            case .ownerAddress:
                optionalFilter = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .address(wallet.address)).flatMap { (filter: $0, textEquivalent: "\(filterName)=\(wallet.address.eip55String)") }
            case .label, .contractAddress, .symbol:
                optionalFilter = nil
            }
        } else {
            //TODO support things like "$prefix-{tokenId}"
            optionalFilter = nil
        }
        guard let (filterValue, textEquivalent) = optionalFilter else { return nil }
        guard let filterValueTypedForEventFilters = filterValue.coerceToArgumentTypeForEventFilter(parameterType) else { return nil }
        return (filter: [filterValueTypedForEventFilters], textEquivalent: textEquivalent)
    }
}
