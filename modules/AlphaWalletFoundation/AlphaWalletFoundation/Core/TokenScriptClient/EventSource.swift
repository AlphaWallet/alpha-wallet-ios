// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift
import Combine

public final class EventSource: NSObject {
    private var wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let config: Config
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.eventSource.updateQueue")
    private let enabledServers: [RPCServer]
    private var cancellable = Set<AnyCancellable>()
    private let tokensService: TokenProvidable

    public init(wallet: Wallet, tokensService: TokenProvidable, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, config: Config) {
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.config = config
        self.enabledServers = config.enabledServers
        self.tokensService = tokensService
        super.init()
    }

    public func start() {
        guard !config.development.isAutoFetchingDisabled else { return }

        subscribeForTokenChanges()
        subscribeForTokenScriptFileChanges()
    }

    private func subscribeForTokenChanges() {
        tokensService.tokensPublisher(servers: enabledServers)
            .receive(on: queue)
            .sink { [weak self] _ in
                self?.fetchEthereumEvents()
            }.store(in: &cancellable)
    }

    private func subscribeForTokenScriptFileChanges() {
        //TODO this is firing twice for each contract. We can be more efficient
        assetDefinitionStore.bodyChange
            .receive(on: queue)
            .compactMap { [tokensService] in tokensService.token(for: $0) }
            .sink { [weak self] token in
                guard let strongSelf = self else { return }

                for each in strongSelf.fetchMappedContractsAndServers(token: token) {
                    strongSelf.fetchEvents(forTokenContract: each.contract, server: each.server)
                }
            }.store(in: &cancellable)
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

    private func fetchEvents(forTokenContract contract: AlphaWallet.Address, server: RPCServer) {
        guard let token = tokensService.token(for: contract, server: server) else { return }
        eventsDataStore.deleteEvents(for: contract)

        when(resolved: fetchEventsByTokenId(forToken: token))
            .done { _ in }
            .cauterize()
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

    private func fetchEventsByTokenId(forToken token: Token) -> [Promise<Void>] {
        return getEventOriginsAndTokenIds(forToken: token)
            .flatMap { value in
                value.tokenIds.map {
                    EventSource.functional.fetchEvents(forTokenId: $0, token: token, eventOrigin: value.eventOrigin, wallet: wallet, eventsDataStore: eventsDataStore, queue: queue)
                }
            }
    }

    private func fetchEthereumEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for instances", limit: 15, autoRun: true) { [weak self] in
                self?.queue.async {
                    self?.fetchEthereumEventsImpl()
                }
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func fetchEthereumEventsImpl() {
        guard !isFetching else { return }
        isFetching = true

        let promises = tokensService.tokens(for: enabledServers).map { fetchEventsByTokenId(forToken: $0) }.flatMap { $0 }
        when(resolved: promises).done { [weak self] _ in
            self?.isFetching = false
        }
    }
}

extension EventSource {
    class functional {}
}

extension EventSource.functional {

    static func fetchEvents(forTokenId tokenId: TokenId, token: Token, eventOrigin: EventOrigin, wallet: Wallet, eventsDataStore: NonActivityEventsDataStore, queue: DispatchQueue) -> Promise<Void> {
        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam = eventOrigin
            .parameters
            .filter { $0.isIndexed }
            .map { Self.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue, wallet: wallet) }

        let oldEvent = eventsDataStore
            .getLastMatchingEventSortedByBlockNumber(for: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
        let fromBlock: EventFilter.Block
        if let newestEvent = oldEvent {
            fromBlock = .blockNumber(UInt64(newestEvent.blockNumber + 1))
        } else {
            fromBlock = .blockNumber(0)
        }
        let addresses = [EthereumAddress(address: eventOrigin.contract)]
        let parameterFilters = filterParam.map { $0?.filter }

        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: addresses, parameterFilters: parameterFilters)

        return getEventLogs(withServer: token.server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: queue)
        .done(on: queue, { result -> Void in
            let events = result.compactMap {
                Self.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, contractAddress: token.contractAddress, server: token.server)
            }

            eventsDataStore.addOrUpdate(events: events)
        }).recover(on: queue, { e in
            error(value: e, rpcServer: token.server, address: token.contractAddress)
        })
    }

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        let prefix = "${"
        let suffix = "}"
        guard string.hasPrefix(prefix) && string.hasSuffix(suffix) else { return nil }
        let value = string.substring(with: prefix.count..<(string.count - suffix.count))
        return AssetImplicitAttributes(rawValue: value)
    }

    private static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, contractAddress: AlphaWallet.Address, server: RPCServer) -> EventInstanceValue? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        let decodedResult = Self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventInstanceValue(contract: eventOrigin.contract, tokenContract: contractAddress, server: server, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), logIndex: Int(logIndex), filter: filterText, json: json)
    }

    private static func formFilterFrom(fromParameter parameter: EventParameter, tokenId: TokenId, filterName: String, filterValue: String, wallet: Wallet) -> (filter: [EventFilterable], textEquivalent: String)? {
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
