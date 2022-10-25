// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Combine
import AlphaWalletWeb3

final class EventSource: NSObject {
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let config: Config
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.eventSource.updateQueue")
    private let enabledServers: [RPCServer]
    private var cancellable = Set<AnyCancellable>()
    private let tokensService: TokenProvidable
    private let eventFetcher: EventFetcher

    init(wallet: Wallet, tokensService: TokenProvidable, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, config: Config, getEventLogs: GetEventLogs) {
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.config = config
        self.enabledServers = config.enabledServers
        self.tokensService = tokensService
        self.eventFetcher = EventFetcher(getEventLogs: getEventLogs, wallet: wallet)
        super.init()
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
        //TODO this is firing twice for each contract. We can be more efficient
        assetDefinitionStore.bodyChange
            .receive(on: queue)
            .compactMap { [tokensService] in tokensService.token(for: $0) }
            .sink { [weak self] in self?.fetchEvents(for: $0) }
            .store(in: &cancellable)
    }

    private func fetchEvents(for token: Token) {
        for each in fetchMappedContractsAndServers(token: token) {
            guard let token = tokensService.token(for: each.contract, server: each.server) else { return }
            eventsDataStore.deleteEvents(for: each.contract)

            fetchEventsByTokenId(for: token)
                .done { _ in }
                .cauterize()
        }
    }

    private func fetchMappedContractsAndServers(token: Token) -> [(contract: AlphaWallet.Address, server: RPCServer)] {
        var values: [(contract: AlphaWallet.Address, server: RPCServer)] = []
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return [] }
        switch server {
        case .any:
            values = enabledServers.map { (contract: token.contractAddress, server: $0) }
        case .server(let server):
            values = [(contract: token.contractAddress, server: server)]
        }

        return values
    }

    private func getEventOriginsAndTokenIds(forToken token: Token) -> [(eventOrigin: EventOrigin, tokenIds: [TokenId])] {
        var cards: [(eventOrigin: EventOrigin, tokenIds: [TokenId])] = []
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        guard !xmlHandler.attributesWithEventSource.isEmpty else { return [] }

        for each in xmlHandler.attributesWithEventSource {
            guard let eventOrigin = each.eventOrigin else { continue }
            let tokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet, isSourcedFromEvents: false)
            let tokenIds = tokenHolders.flatMap { $0.tokenIds }

            cards.append((eventOrigin, tokenIds))
        }

        return cards
    }

    private func fetchEventsByTokenId(for token: Token) -> Promise<Void> {
        let promises = getEventOriginsAndTokenIds(forToken: token)
            .flatMap { value in
                value.tokenIds.map { tokenId -> Promise<Void> in
                    let eventOrigin = value.eventOrigin
                    let oldEvent = eventsDataStore.getLastMatchingEventSortedByBlockNumber(for: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
                    return eventFetcher.fetchEvents(tokenId: tokenId, token: token, eventOrigin: eventOrigin, oldEvent: oldEvent)
                        .map(on: queue, { [eventsDataStore] events in
                            eventsDataStore.addOrUpdate(events: events)
                        })
                }
            }
        return when(resolved: promises).map { _ in }
    }

    private func fetchAllEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for instances", limit: 15, autoRun: true) { [weak self] in
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

        let promises = tokensService.tokens(for: enabledServers).map { fetchEventsByTokenId(for: $0) }.flatMap { $0 }
        when(resolved: promises).done { [weak self] _ in
            self?.isFetching = false
        }
    }
}

extension EventSource {
    class functional {}
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
