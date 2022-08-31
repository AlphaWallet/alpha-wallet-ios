// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import BigInt
import PromiseKit
import web3swift
import Combine

public final class EventSourceForActivities {
    private var wallet: Wallet
    private let config: Config
    private let tokensService: TokenProvidable
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.EventSourceForActivities.updateQueue")
    private let enabledServers: [RPCServer]
    private var cancellable = Set<AnyCancellable>()

    public init(wallet: Wallet, config: Config, tokensService: TokenProvidable, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsActivityDataStoreProtocol) {
        self.wallet = wallet
        self.config = config
        self.tokensService = tokensService
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.enabledServers = config.enabledServers
    }

    public func start() {
        guard !config.development.isAutoFetchingDisabled else { return }

        subscribeForTokenChanges()
        subscribeForTokenScriptFileChanges() 
    }

    private func subscribeForTokenChanges() {
        tokensService.tokensPublisher(servers: enabledServers)
            .receive(on: queue)
            .sink { [weak self] _ in self?.fetchEthereumEvents() }
            .store(in: &cancellable)
    }

    private func subscribeForTokenScriptFileChanges() {
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

        when(resolved: fetchEvents(forToken: token))
            .done { _ in }
            .cauterize()
    }

    private func getActivityCards(forToken token: Token) -> [TokenScriptCard] {
        var cards: [TokenScriptCard] = []

        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        cards = xmlHandler.activityCards

        return cards
    }

    private func fetchEvents(forToken token: Token) -> [Promise<Void>] {
        return getActivityCards(forToken: token)
            .map { EventSourceForActivities.functional.fetchEvents(tokenContract: token.contractAddress, server: token.server, card: $0, eventsDataStore: eventsDataStore, queue: queue, wallet: wallet) }
    }

    private func fetchEthereumEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for Activities", limit: 60, autoRun: true) { [weak self] in
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

        let promises = tokensService.tokens(for: enabledServers).map { fetchEvents(forToken: $0) }.flatMap { $0 }

        when(resolved: promises).done { [weak self] _ in
            self?.isFetching = false
        }
    }
}

extension EventSourceForActivities {
    class functional {}
}

extension EventSourceForActivities.functional {
    static func fetchEvents(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, eventsDataStore: EventsActivityDataStoreProtocol, queue: DispatchQueue, wallet: Wallet) -> Promise<Void> {

        let eventOrigin = card.eventOrigin
        let (filterName, filterValue) = eventOrigin.eventFilter
        typealias functional = EventSourceForActivities.functional
        let filterParam = eventOrigin.parameters
            .filter { $0.isIndexed }
            .map { functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: wallet) }

        if filterParam.allSatisfy({ $0 == nil }) {
            //TODO log to console as diagnostic
            return .init(error: PMKError.cancelled)
        }

        let oldEvent = eventsDataStore
        .getLastMatchingEventSortedByBlockNumber(for: eventOrigin.contract, tokenContract: tokenContract, server: server, eventName: eventOrigin.eventName)

        let fromBlock: (EventFilter.Block, UInt64)
        if let newestEvent = oldEvent {
            let value = UInt64(newestEvent.blockNumber + 1)
            fromBlock = (.blockNumber(value), value)
        } else {
            fromBlock = (.blockNumber(0), 0)
        }
        let parameterFilters = filterParam.map { $0?.filter }
        let addresses = [EthereumAddress(address: eventOrigin.contract)]
        let toBlock = server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)
        let eventFilter =  EventFilter(fromBlock: fromBlock.0, toBlock: toBlock, addresses: addresses, parameterFilters: parameterFilters)

        return getEventLogs(withServer: server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: queue)
        .then(on: queue, { events -> Promise<[EventActivityInstance]> in
            let promises = events.compactMap { event -> Promise<EventActivityInstance?> in
                guard let blockNumber = event.eventLog?.blockNumber else {
                    return .value(nil)
                }

                return GetBlockTimestamp()
                    .getBlockTimestamp(blockNumber, onServer: server)
                    .map(on: queue, { date in
                        Self.convertEventToDatabaseObject(event, date: date, filterParam: filterParam, eventOrigin: eventOrigin, tokenContract: tokenContract, server: server)
                    }).recover(on: queue, { _ -> Promise<EventActivityInstance?> in
                        return .value(nil)
                    })
            }

            return when(resolved: promises).map(on: queue, { values -> [EventActivityInstance] in
                values.compactMap { $0.optionalValue }.compactMap { $0 }
            })
        }).map(on: queue, { events -> Void in
            eventsDataStore.addOrUpdate(events: events)
        }).recover(on: queue, { e in
            error(value: e, rpcServer: server, address: tokenContract)
        })
    }

    private static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, tokenContract: AlphaWallet.Address, server: RPCServer) -> EventActivityInstance? {
        guard let eventLog = event.eventLog else { return nil }

        let transactionId = eventLog.transactionHash.hexEncoded
        let decodedResult = EventSource.functional.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventActivityInstance(contract: eventOrigin.contract, tokenContract: tokenContract, server: server, date: date, eventName: eventOrigin.eventName, blockNumber: Int(eventLog.blockNumber), transactionId: transactionId, transactionIndex: Int(eventLog.transactionIndex), logIndex: Int(eventLog.logIndex), filter: filterText, json: json)
    }

    private static func formFilterFrom(fromParameter parameter: EventParameter, filterName: String, filterValue: String, wallet: Wallet) -> (filter: [EventFilterable], textEquivalent: String)? {
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
