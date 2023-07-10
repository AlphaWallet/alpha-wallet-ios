// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletTokenScript
import AlphaWalletWeb3
import BigInt

final class EventSourceForActivities {
    typealias EventForActivityPublisher = AnyPublisher<[EventActivityInstance], Never>

    private let config: Config
    private let tokensService: TokensService
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var cancellable = Set<AnyCancellable>()
    private let sessionsProvider: SessionsProvider
    private let eventFetcher: TokenEventsForActivitiesTickersFetcher
    private let tokenScriptChanges: TokenScriptChangedTokens
    private var workers: [RPCServer: ChainTokenEventsForActivitiesWorker] = [:]

    init(wallet: Wallet,
         config: Config,
         tokensService: TokensService,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: EventsActivityDataStoreProtocol,
         sessionsProvider: SessionsProvider) {

        self.config = config
        self.tokensService = tokensService
        self.eventsDataStore = eventsDataStore
        self.sessionsProvider = sessionsProvider

        self.eventFetcher = TokenEventsForActivitiesTickersFetcher(
            eventsDataStore: eventsDataStore,
            sessionsProvider: sessionsProvider,
            eventFetcher: EventForActivitiesFetcher(sessionsProvider: sessionsProvider))

        self.tokenScriptChanges = TokenScriptChangedTokens(
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            assetDefinitionStore: assetDefinitionStore)
    }

    func start() {
        guard !config.development.isAutoFetchingDisabled else { return }

        sessionsProvider.sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let strongSelf = self else { return }

                let addedOrFetchedWorkers = strongSelf.addOrFetchWorker(sessions: sessions)
                strongSelf.removeWorkers(except: addedOrFetchedWorkers)
            }.store(in: &cancellable)
    }

    func stop() {
        cancellable.cancellAll()
    }

    private func addOrFetchWorker(sessions: ServerDictionary<WalletSession>) -> [RPCServer: ChainTokenEventsForActivitiesWorker] {
        var addedOrFetchedWorkers: [RPCServer: ChainTokenEventsForActivitiesWorker] = [:]
        for session in sessions {
            if let worker = self.workers[session.key] {
                addedOrFetchedWorkers[session.key] = worker
            } else {
                let worker = ChainTokenEventsForActivitiesWorker(
                    tokensService: tokensService,
                    session: session.value,
                    eventsFetcher: eventFetcher,
                    tokenScriptChanges: tokenScriptChanges)

                worker.start()

                addedOrFetchedWorkers[session.key] = worker
                self.workers[session.key] = worker
            }
        }

        return addedOrFetchedWorkers
    }

    private func removeWorkers(except: [RPCServer: ChainTokenEventsForActivitiesWorker]) {
        let providersToDelete = self.workers.keys.filter { k in !except.contains(where: { $0.key == k }) }
        providersToDelete.forEach {
            self.workers[$0]?.stop()
            self.workers[$0] = nil
        }
    }

    class TokenScriptChangedTokens {
        private let queue = DispatchQueue(label: "com.eventSource.tokenScriptChangedTokens")
        private let tokensService: TokensService
        private let sessionsProvider: SessionsProvider
        private let assetDefinitionStore: AssetDefinitionStore

        var tokenScriptChanged: AnyPublisher<[Token], Never> {
            assetDefinitionStore.bodyChange
                .receive(on: queue)
                .compactMap { [tokensService] in tokensService.token(for: $0) }
                .compactMap { [weak self] in self?.map(token: $0) }
                .share()
                .eraseToAnyPublisher()
        }

        init(tokensService: TokensService,
             sessionsProvider: SessionsProvider,
             assetDefinitionStore: AssetDefinitionStore) {

            self.assetDefinitionStore = assetDefinitionStore
            self.sessionsProvider = sessionsProvider
            self.tokensService = tokensService
        }

        private func map(token: Token) -> [Token] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }

            let xmlHandler = XMLHandler(contract: token.contractAddress, tokenType: token.type, assetDefinitionStore: assetDefinitionStore)
            guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return [] }
            switch server {
            case .any:
                let enabledServers = sessionsProvider.activeSessions.map { $0.key }
                return enabledServers.compactMap { tokensService.token(for: token.contractAddress, server: $0) }
            case .server(let server):
                return [token]
            }
        }
    }

    class ChainTokenEventsForActivitiesWorker {
        private typealias FetchRequest = EventSource.ChainTokenEventsForTickersWorker.FetchRequest
        private typealias RequestOrCancellation = EventSource.ChainTokenEventsForTickersWorker.RequestOrCancellation

        private let queue = DispatchQueue(label: "com.eventSource.chainTokenEventsForTickersWorker")
        private let tokensService: TokensService
        private let session: WalletSession
        private let eventsFetcher: TokenEventsForActivitiesTickersFetcher
        private var workers: [AlphaWallet.Address: TokenEventsForActivitiesWorker] = [:]
        private var cancellable: AnyCancellable?
        private let tokenScriptChanges: TokenScriptChangedTokens

        init(tokensService: TokensService,
             session: WalletSession,
             eventsFetcher: TokenEventsForActivitiesTickersFetcher,
             tokenScriptChanges: TokenScriptChangedTokens) {

            self.tokenScriptChanges = tokenScriptChanges
            self.eventsFetcher = eventsFetcher
            self.session = session
            self.tokensService = tokensService
        }

        private func deleteAllWorkers() {
            workers.forEach { $0.value.cancel() }
            workers.removeAll()
        }

        private func deleteWorker(contract: AlphaWallet.Address) {
            workers[contract]?.cancel()
            workers[contract] = nil
        }

        private func addOrFetchWorkers(requests: [EventSource.ChainTokenEventsForTickersWorker.FetchRequest]) -> [AlphaWallet.Address: TokenEventsForActivitiesWorker] {
            var workers: [AlphaWallet.Address: TokenEventsForActivitiesWorker] = [:]

            for request in requests {
                if let worker = self.workers[request.token.contractAddress] {
                    workers[request.token.contractAddress] = worker

                    worker.send(request: request)
                } else {
                    let worker = TokenEventsForActivitiesWorker(
                        request: request,
                        eventsFetcher: eventsFetcher)

                    workers[request.token.contractAddress] = worker
                    self.workers[request.token.contractAddress] = worker
                }
            }

            return workers
        }

        private func buildFetchOrCancellationRequests(server: RPCServer) -> AnyPublisher<(requests: [FetchRequest], cancellations: [AlphaWallet.Address]), Never> {
            let tokenScriptChanged = tokenScriptChanges.tokenScriptChanged
                .receive(on: queue)
                .map { $0.filter { $0.server == server } }
                .map { $0.map { RequestOrCancellation.request(FetchRequest(token: $0, policy: .force)) } }

            let tokensChangesetPublisher = tokensService.tokensChangesetPublisher(servers: [server])
                .receive(on: queue)
                .compactMap { changeset -> [RequestOrCancellation]? in
                    switch changeset {
                    case .initial(let tokens):
                        return tokens.map { RequestOrCancellation.request(FetchRequest(token: $0, policy: .force)) }
                    case .error:
                        return nil
                    case .update(let tokens, let deletionsIndices, let insertionsIndices, let modificationsIndices):
                        let insertions = insertionsIndices.map { tokens[$0] }
                            .filter { $0.shouldDisplay }
                            .map { RequestOrCancellation.request(FetchRequest(token: $0, policy: .force)) }

                        let modifications = modificationsIndices.map { tokens[$0] }
                            .filter { $0.shouldDisplay }
                            .map { RequestOrCancellation.request(FetchRequest(token: $0, policy: .waitForCurrent)) }

                        let wereHiddenByUser = modificationsIndices.map { tokens[$0] }
                            .filter { !$0.shouldDisplay }
                            .map { RequestOrCancellation.cancel(contract: $0.contractAddress) }

                        let deletions = deletionsIndices.map { tokens[$0] }
                            .map { RequestOrCancellation.cancel(contract: $0.contractAddress) }

                        return insertions + modifications + deletions + wereHiddenByUser
                    }
                }

            return Publishers.Merge(tokensChangesetPublisher, tokenScriptChanged)
                .map { values -> (requests: [FetchRequest], cancellations: [AlphaWallet.Address]) in
                    let cancellations = values.compactMap { value -> AlphaWallet.Address? in
                        guard case .cancel(let contract) = value else { return nil }
                        return contract
                    }

                    let requests = values.compactMap { value -> FetchRequest? in
                        guard case .request(let request) = value else { return nil }
                        return request
                    }
                    return (requests: requests, cancellations: cancellations)
                }.eraseToAnyPublisher()
        }

        func start() {
            cancellable = buildFetchOrCancellationRequests(server: session.server)
                .sink(receiveCompletion: { [weak self] result in
                    guard let strongSelf = self else { return }
                    guard case .failure = result else { return }

                    strongSelf.deleteAllWorkers()
                }, receiveValue: { [weak self] data in
                    guard let strongSelf = self else { return }

                    let workers = strongSelf.addOrFetchWorkers(requests: data.requests)

                    data.cancellations.forEach { strongSelf.deleteWorker(contract: $0) }
                })
        }

        func stop() {
            cancellable?.cancel()

            deleteAllWorkers()
        }

        private class TokenEventsForActivitiesWorker {
            private var request: FetchRequest
            private let timer = CombineTimer(interval: 65)
            private let subject = PassthroughSubject<FetchRequest, Never>()
            private var cancellable: AnyCancellable?

            var debouce: TimeInterval = 60

            init(request: FetchRequest, eventsFetcher: TokenEventsForActivitiesTickersFetcher) {
                self.request = request

                let timedFetch = timer.publisher.map { _ in self.request }.share()
                let timedOrWaitForCurrent = Publishers.Merge(timedFetch, subject.filter { $0.policy == .waitForCurrent })
                    .debounce(for: .seconds(debouce), scheduler: RunLoop.main)
                let force = subject.filter { $0.policy == .force }
                let initial = Just(request)

                cancellable = Publishers.Merge3(initial, force, timedOrWaitForCurrent)
                    .receive(on: DispatchQueue.global())
                    .flatMap { [eventsFetcher] in eventsFetcher.fetchEvents(token: $0.token) }
                    .sink { _ in }
            }

            func send(request: FetchRequest) {
                self.request = request
                subject.send(request)
            }

            func cancel() {
                subject.send(completion: .finished)
                cancellable?.cancel()
            }
        }
    }

    class TokenEventsForActivitiesTickersFetcher {
        private let eventsDataStore: EventsActivityDataStoreProtocol
        private let eventFetcher: EventForActivitiesFetcher
        private let sessionsProvider: SessionsProvider

        init(eventsDataStore: EventsActivityDataStoreProtocol,
             sessionsProvider: SessionsProvider,
             eventFetcher: EventForActivitiesFetcher) {

            self.sessionsProvider = sessionsProvider
            self.eventFetcher = eventFetcher
            self.eventsDataStore = eventsDataStore
        }

        private func getActivityCards(token: Token) -> [TokenScriptCard] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }
            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
            guard xmlHandler.hasAssetDefinition else { return [] }
            return xmlHandler.activityCards
        }

        func fetchEvents(token: Token) -> EventForActivityPublisher {
            let publishers = getActivityCards(token: token)
                .map { [eventFetcher] card -> EventForActivityPublisher in
                    let eventOrigin = card.eventOrigin
                    let oldEvent = eventsDataStore.getLastMatchingEventSortedByBlockNumber(
                        for: eventOrigin.contract,
                        tokenContract: token.contractAddress,
                        server: token.server,
                        eventName: eventOrigin.eventName)

                    return eventFetcher.fetchEvents(token: token, card: card, oldEventBlockNumber: oldEvent?.blockNumber)
                        .handleEvents(receiveOutput: { [eventsDataStore] in eventsDataStore.addOrUpdate(events: $0) })
                        .replaceError(with: [])
                        .eraseToAnyPublisher()
                }

            return Publishers.MergeMany(publishers)
                .collect()
                .map { $0.flatMap { $0 } }
                .eraseToAnyPublisher()
        }
    }
}

extension EventSourceForActivities {
    enum functional {}
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
