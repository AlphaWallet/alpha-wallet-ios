// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletTokenScript
import AlphaWalletWeb3

final class EventSource {
    typealias EventPublisher = AnyPublisher<[EventInstanceValue], Never>

    private let config: Config
    private var cancellable = Set<AnyCancellable>()
    private let tokensService: TokensService
    private let sessionsProvider: SessionsProvider
    private let eventFetcher: TokenEventsForTickersFetcher
    private let tokenScriptChanges: TokenScriptChangedTokens
    private var workers: [RPCServer: ChainTokenEventsForTickersWorker] = [:]

    init(wallet: Wallet,
         tokensService: TokensService,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: NonActivityEventsDataStore,
         config: Config,
         sessionsProvider: SessionsProvider) {

        self.sessionsProvider = sessionsProvider
        self.config = config
        self.tokensService = tokensService

        self.eventFetcher = TokenEventsForTickersFetcher(
            eventsDataStore: eventsDataStore,
            sessionsProvider: sessionsProvider,
            eventFetcher: EventFetcher(sessionsProvider: sessionsProvider))

        self.tokenScriptChanges = TokenScriptChangedTokens(
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            eventsDataStore: eventsDataStore,
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

    private func addOrFetchWorker(sessions: ServerDictionary<WalletSession>) -> [RPCServer: ChainTokenEventsForTickersWorker] {
        var addedOrFetchedWorkers: [RPCServer: ChainTokenEventsForTickersWorker] = [:]
        for session in sessions {
            if let worker = self.workers[session.key] {
                addedOrFetchedWorkers[session.key] = worker
            } else {
                let worker = ChainTokenEventsForTickersWorker(
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

    private func removeWorkers(except: [RPCServer: ChainTokenEventsForTickersWorker]) {
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
        private let eventsDataStore: NonActivityEventsDataStore

        var tokenScriptChanged: AnyPublisher<[Token], Never> {
            assetDefinitionStore.bodyChange
                .receive(on: queue)
                .compactMap { [tokensService] in tokensService.token(for: $0) }
                .compactMap { self.tokensBasedOnTokenScriptServer(token: $0) }
                .handleEvents(receiveOutput: { [eventsDataStore] in $0.map { eventsDataStore.deleteEvents(for: $0.contractAddress) } })
                .share()
                .eraseToAnyPublisher()
        }

        init(tokensService: TokensService,
             sessionsProvider: SessionsProvider,
             eventsDataStore: NonActivityEventsDataStore,
             assetDefinitionStore: AssetDefinitionStore) {

            self.eventsDataStore = eventsDataStore
            self.assetDefinitionStore = assetDefinitionStore
            self.sessionsProvider = sessionsProvider
            self.tokensService = tokensService
        }

        private func tokensBasedOnTokenScriptServer(token: Token) -> [Token] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }
            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
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

    class ChainTokenEventsForTickersWorker {
        private let queue = DispatchQueue(label: "com.eventSource.chainTokenEventsForTickersWorker")
        private let tokensService: TokensService
        private let session: WalletSession
        private let eventsFetcher: TokenEventsForTickersFetcher
        private var workers: [AlphaWallet.Address: TokenEventsForTickersWorker] = [:]
        private var cancellable: AnyCancellable?
        private let tokenScriptChanges: TokenScriptChangedTokens

        init(tokensService: TokensService,
             session: WalletSession,
             eventsFetcher: TokenEventsForTickersFetcher,
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

        enum FetchPolicy {
            case force
            case waitForCurrent
        }

        struct FetchRequest {
            let token: Token
            let policy: FetchPolicy
        }

        enum RequestOrCancellation {
            case request(FetchRequest)
            case cancel(contract: AlphaWallet.Address)
        }

        private func addOrFetchWorkers(requests: [FetchRequest]) -> [AlphaWallet.Address: TokenEventsForTickersWorker] {
            var workers: [AlphaWallet.Address: TokenEventsForTickersWorker] = [:]

            for request in requests {
                if let worker = self.workers[request.token.contractAddress] {
                    workers[request.token.contractAddress] = worker

                    worker.send(request: request)
                } else {
                    let worker = TokenEventsForTickersWorker(
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

        private class TokenEventsForTickersWorker {
            private var request: FetchRequest
            //NOTE: Its crucial not to set times time as as debounce, cause all timed calls will be blocked
            private let timer = CombineTimer(interval: 35)
            private let subject = PassthroughSubject<FetchRequest, Never>()
            private var cancellable: AnyCancellable?

            var debouce: TimeInterval = 30

            init(request: FetchRequest, eventsFetcher: TokenEventsForTickersFetcher) {
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

    class TokenEventsForTickersFetcher {
        private let eventsDataStore: NonActivityEventsDataStore
        private let eventFetcher: EventFetcher
        private let sessionsProvider: SessionsProvider

        init(eventsDataStore: NonActivityEventsDataStore,
             sessionsProvider: SessionsProvider,
             eventFetcher: EventFetcher) {

            self.sessionsProvider = sessionsProvider
            self.eventFetcher = eventFetcher
            self.eventsDataStore = eventsDataStore
        }

        private func getEventOriginsAndTokenIds(token: Token) -> [(eventOrigin: EventOrigin, tokenIds: [TokenId])] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }

            var cards: [(eventOrigin: EventOrigin, tokenIds: [TokenId])] = []
            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
            guard xmlHandler.hasAssetDefinition else { return [] }
            guard !xmlHandler.attributesWithEventSource.isEmpty else { return [] }

            for each in xmlHandler.attributesWithEventSource {
                guard let eventOrigin = each.eventOrigin else { continue }

                let tokenHolders = session.tokenAdaptor.getTokenHolders(token: token, isSourcedFromEvents: false)
                let tokenIds = tokenHolders.flatMap { $0.tokenIds }

                cards.append((eventOrigin, tokenIds))
            }

            return cards
        }

        func fetchEvents(token: Token) -> EventPublisher {
            let publishers = getEventOriginsAndTokenIds(token: token)
                .flatMap { value in
                    value.tokenIds.map { tokenId -> EventPublisher in
                        let eventOrigin = value.eventOrigin
                        let oldEvent = eventsDataStore.getLastMatchingEventSortedByBlockNumber(
                            for: eventOrigin.contract,
                            tokenContract: token.contractAddress,
                            server: token.server,
                            eventName: eventOrigin.eventName)

                        return eventFetcher
                            .fetchEvents(tokenId: tokenId, token: token, eventOrigin: eventOrigin, oldEventBlockNumber: oldEvent?.blockNumber)
                            .handleEvents(receiveOutput: { [eventsDataStore] in eventsDataStore.addOrUpdate(events: $0) })
                            .replaceError(with: [])
                            .eraseToAnyPublisher()
                    }
                }

            return Publishers.MergeMany(publishers)
                .collect()
                .map { $0.flatMap { $0 } }
                .eraseToAnyPublisher()
        }
    }
}

extension EventSource {
    enum functional {}
}

extension EventSource.functional {

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        let prefix = "${"
        let suffix = "}"
        guard string.hasPrefix(prefix) && string.hasSuffix(suffix) else { return nil }
        let value = string.substring(with: prefix.count..<(string.count - suffix.count))
        return AssetImplicitAttributes(rawValue: value)
    }

    static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, contractAddress: AlphaWallet.Address, server: RPCServer) -> EventInstanceValue? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        let decodedResult = Self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventInstanceValue(contract: eventOrigin.contract, tokenContract: contractAddress, server: server, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), logIndex: Int(logIndex), filter: filterText, json: json)
    }

    static func formFilterFrom(fromParameter parameter: EventParameter, tokenId: TokenId, filterName: String, filterValue: String, wallet: Wallet) -> (filter: [EventFilterable], textEquivalent: String)? {
        guard parameter.name == filterName else { return nil }
        guard let parameterType = SolidityType(rawValue: parameter.type) else { return nil }
        let optionalFilter: (filter: AssetAttributeValueUsableAsFunctionArguments, textEquivalent: String)?
        if let implicitAttribute = Self.convertToImplicitAttribute(string: filterValue) {
            switch implicitAttribute {
            case .tokenId:
                optionalFilter = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .uint(tokenId)).flatMap { (filter: $0, textEquivalent: "\(filterName)=\(tokenId)") }
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

    static func convertToJsonCompatible(dictionary: [String: Any]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value -> (String, Any)? in
            switch value {
            case let address as EthereumAddress:
                return (key, address.address)
            case let data as Data:
                return (key, data.hexEncoded)
            case let string as String:
                return (key, string)
            case let bigUInt as BigUInt:
                //Must not do `Int(bigUInt)` because it crashes upon overflow
                return (key, String(bigUInt))
            default:
                //We only accept known types, otherwise serializing to JSON will crash
                return nil
            }
        })
    }

}
