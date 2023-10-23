// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletTokenScript
import AlphaWalletWeb3

// swiftlint:disable type_body_length
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
                .flatMap { [tokensService] address in asFuture { await tokensService.token(for: address) } }.compactMap { $0 }
                .flatMap { token in asFuture { await self.tokensBasedOnTokenScriptServer(token: token) } }
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

        private func tokensBasedOnTokenScriptServer(token: Token) async -> [Token] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }
            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
            guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return [] }
            switch server {
            case .any:
                let enabledServers = sessionsProvider.activeSessions.map { $0.key }
                return await enabledServers.asyncCompactMap { server in await tokensService.token(for: token.contractAddress, server: server) }
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
                    .flatMap { [eventsFetcher] request in
                        eventsFetcher.fetchEvents(token: request.token)
                    }
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

        private func getEventOriginsAndTokenIds(token: Token) async -> [(eventOrigin: EventOrigin, tokenIds: [TokenId])] {
            guard let session = sessionsProvider.session(for: token.server) else { return [] }

            var cards: [(eventOrigin: EventOrigin, tokenIds: [TokenId])] = []
            let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)
            guard xmlHandler.hasAssetDefinition else { return [] }
            guard !xmlHandler.attributesWithEventSource.isEmpty else { return [] }

            for each in xmlHandler.attributesWithEventSource {
                guard let eventOrigin = each.eventOrigin else { continue }

                let tokenHolders = await session.tokenAdaptor.getTokenHolders(token: token, isSourcedFromEvents: false)
                let tokenIds = tokenHolders.flatMap { $0.tokenIds }

                cards.append((eventOrigin, tokenIds))
            }

            return cards
        }

        func fetchEvents(token: Token) -> EventPublisher {
            let subject = PassthroughSubject<[EventInstanceValue], Never>()
            Task { @MainActor in
                let eventsAndTokenIds: [(eventOrigin: EventOrigin, tokenIds: [TokenId])] = await self.getEventOriginsAndTokenIds(token: token)
                let all: [EventInstanceValue] = try await eventsAndTokenIds.asyncMap { (value: (eventOrigin: EventOrigin, tokenIds: [TokenId])) in
                    let what: [EventInstanceValue] = try await value.tokenIds.asyncFlatMap { tokenId in
                        let eventOrigin = value.eventOrigin
                        let oldEvent = await self.eventsDataStore.getLastMatchingEventSortedByBlockNumber(for: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
                        let events: [EventInstanceValue] = try await self.eventFetcher.fetchEvents(tokenId: tokenId, token: token, eventOrigin: eventOrigin, oldEventBlockNumber: oldEvent?.blockNumber)
                        self.eventsDataStore.addOrUpdate(events: events)
                        return events
                    }
                    return what
                }.flatMap { $0 }
                subject.send(all)
            }
            return subject.eraseToAnyPublisher()
        }
    }

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        let prefix = "${"
        let suffix = "}"
        guard string.hasPrefix(prefix) && string.hasSuffix(suffix) else { return nil }
        let value = string.substring(with: prefix.count..<(string.count - suffix.count))
        return AssetImplicitAttributes(rawValue: value)
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
// swiftlint:enable type_body_length