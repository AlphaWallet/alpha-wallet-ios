// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift
import Combine

extension PromiseKit.Result {
    var optionalValue: T? {
        switch self {
        case .fulfilled(let value):
            return value
        case .rejected:
            return nil
        }
    }
}

final class EventSourceCoordinator: NSObject {
    private var wallet: Wallet
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let config: Config
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.eventSourceCoordinator.updateQueue")
    private let enabledServers: [RPCServer]
    private var cancellable = Set<AnyCancellable>()
    
    init(wallet: Wallet, tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, config: Config) {
        self.wallet = wallet
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.config = config
        self.enabledServers = config.enabledServers

        super.init()
    }

    func start() {
        setupWatchingTokenChangesToFetchEvents()
        setupWatchingTokenScriptFileChangesToFetchEvents()
    } 

    private func setupWatchingTokenChangesToFetchEvents() {
        tokensDataStore
            .enabledTokenObjectsChangesetPublisher(forServers: enabledServers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchEthereumEvents()
            }.store(in: &cancellable)
    }

    private func setupWatchingTokenScriptFileChangesToFetchEvents() {
        //TODO this is firing twice for each contract. We can be more efficient
        assetDefinitionStore.bodyChange
            .receive(on: RunLoop.main)
            .compactMap { [weak self] in self?.tokensDataStore.token(forContract: $0) }
            .sink { [weak self] token in
                guard let strongSelf = self else { return }

                let xmlHandler = XMLHandler(token: token, assetDefinitionStore: strongSelf.assetDefinitionStore)
                guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return }
                switch server {
                case .any:
                    for each in strongSelf.config.enabledServers {
                        strongSelf.fetchEvents(forTokenContract: token.contractAddress, server: each)
                    }
                case .server(let server):
                    strongSelf.fetchEvents(forTokenContract: token.contractAddress, server: server)
                }
            }.store(in: &cancellable)
    }

    private func fetchEvents(forTokenContract contract: AlphaWallet.Address, server: RPCServer) {
        guard let token = tokensDataStore.token(forContract: contract, server: server) else { return }
        eventsDataStore.deleteEvents(forTokenContract: contract)

        when(resolved: fetchEventsByTokenId(forToken: token))
            .done { _ in }
            .cauterize()
    }

    private func fetchEventsByTokenId(forToken token: TokenObject) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return .init() }
        guard !xmlHandler.attributesWithEventSource.isEmpty else { return .init() }

        var fetchPromises = [Promise<Void>]()
        for each in xmlHandler.attributesWithEventSource {
            guard let eventOrigin = each.eventOrigin else { continue }
            let tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: wallet, isSourcedFromEvents: false)

            for eachTokenHolder in tokenHolders {
                guard let tokenId = eachTokenHolder.tokenIds.first else { continue }
                let promise = EventSourceCoordinator.functional.fetchEvents(config: config, forTokenId: tokenId, token: token, eventOrigin: eventOrigin, wallet: wallet, eventsDataStore: eventsDataStore, queue: queue)
                fetchPromises.append(promise)
            }
        }

        return fetchPromises
    }

    private func fetchEthereumEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for instances", limit: 15, autoRun: true) { [weak self] in
                self?.fetchEthereumEventsImpl()
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func fetchEthereumEventsImpl() {
        guard !isFetching else { return }
        isFetching = true

        let tokens = tokensDataStore.enabledTokenObjects(forServers: enabledServers)
        let promises = tokens.map { fetchEventsByTokenId(forToken: $0) }.flatMap { $0 }
        when(resolved: promises).done { [weak self] _ in
            self?.isFetching = false
        }
    }
}

extension EventSourceCoordinator {
    class functional {}
}

extension EventSourceCoordinator.functional {

    static func fetchEvents(config: Config, forTokenId tokenId: TokenId, token: TokenObject, eventOrigin: EventOrigin, wallet: Wallet, eventsDataStore: NonActivityEventsDataStore, queue: DispatchQueue) -> Promise<Void> {
        if config.development.isAutoFetchingDisabled {
            return Promise { _ in }
        }
        let (promise, seal) = Promise<Void>.pending()

        queue.async {
            let (filterName, filterValue) = eventOrigin.eventFilter
            let filterParam = eventOrigin
                .parameters
                .filter { $0.isIndexed }
                .map { Self.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue, wallet: wallet) }

            let oldEvent = eventsDataStore
                .getLastMatchingEventSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
            let fromBlock: EventFilter.Block
            if let newestEvent = oldEvent {
                fromBlock = .blockNumber(UInt64(newestEvent.blockNumber + 1))
            } else {
                fromBlock = .blockNumber(0)
            }
            let addresses = [EthereumAddress(address: eventOrigin.contract)]
            let parameterFilters = filterParam.map { $0?.filter }

            let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: addresses, parameterFilters: parameterFilters)

            getEventLogs(withServer: token.server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: queue)
            .done(on: queue, { result in
                let events = result.compactMap {
                    Self.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, contractAddress: token.contractAddress, server: token.server)
                }

                eventsDataStore.add(events: events)
                seal.fulfill(())
            }).catch(on: queue, { e in
                error(value: e, rpcServer: token.server, address: token.contractAddress)
                seal.reject(e)
            })
        }

        return promise
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
