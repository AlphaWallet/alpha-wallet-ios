// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

protocol EventSourceCoordinatorType: class {
    func fetchEthereumEvents()
    func fetchEventsByTokenId(forToken token: TokenObject) -> [Promise<Void>]
}

//TODO rename this generic name to reflect that it's for event instances, not for event activity
class EventSourceCoordinator: EventSourceCoordinatorType {
    private var wallet: Wallet
    private let config: Config
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.eventSourceCoordinator.updateQueue")

    init(wallet: Wallet, config: Config, tokensStorages: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.wallet = wallet
        self.config = config
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    func fetchEventsByTokenId(forToken token: TokenObject) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return .init() }
        guard !xmlHandler.attributesWithEventSource.isEmpty else { return .init() }

        var fetchPromises = [Promise<Void>]()
        for each in xmlHandler.attributesWithEventSource {
            guard let eventOrigin = each.eventOrigin else { continue }
            let tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: wallet, isSourcedFromEvents: false)

            for eachTokenHolder in tokenHolders {
                guard let tokenId = eachTokenHolder.tokenIds.first else { continue }
                let promise = fetchEvents(forTokenId: tokenId, token: token, eventOrigin: eventOrigin)
                fetchPromises.append(promise)
            }
        }

        return fetchPromises
    }

    func fetchEthereumEvents() {
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

        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        let fetchPromises = tokensStoragesForEnabledServers.flatMap {
            $0.enabledObject.flatMap { fetchEventsByTokenId(forToken: $0) }
        }

        when(resolved: fetchPromises).done { _ in
            self.isFetching = false
        }
    }

    private func fetchEvents(forTokenId tokenId: TokenId, token: TokenObject, eventOrigin: EventOrigin) -> Promise<Void> {
        return Promise<Void> { seal in
            self.queue.async {
                let (filterName, filterValue) = eventOrigin.eventFilter
                let filterParam = eventOrigin.parameters
                        .filter { $0.isIndexed }
                        .map { self.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue) }
                let contractAddress = token.contractAddress
                let tokenServer = token.server

                self.eventsDataStore.getLastMatchingEventSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: contractAddress, server: tokenServer, eventName: eventOrigin.eventName).map(on: self.queue, { oldEvent -> EventFilter.Block in
                    if let newestEvent = oldEvent {
                        return .blockNumber(UInt64(newestEvent.blockNumber + 1))
                    } else {
                        return .blockNumber(0)
                    }
                }).map(on: self.queue, { fromBlock -> EventFilter in
                    EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: [EthereumAddress(address: eventOrigin.contract)], parameterFilters: filterParam.map { $0?.filter })
                }).then(on: self.queue, { eventFilter in
                    getEventLogs(withServer: tokenServer, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: self.queue)
                }).map(on: self.queue, { result -> [EventInstanceValue] in
                    result.compactMap {
                        self.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, contractAddress: contractAddress, server: tokenServer)
                    }
                }).then(on: self.queue, { events -> Promise<Void> in
                    self.eventsDataStore.add(events: events, forTokenContract: contractAddress)
                }).done(on: self.queue, { _ in
                    seal.fulfill(())
                }).catch(on: self.queue, { e in
                    seal.reject(e)
                })
            }
        }
    }

    private func convertEventToDatabaseObject(_ event: EventParserResultProtocol, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, contractAddress: AlphaWallet.Address, server: RPCServer) -> EventInstanceValue? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        let decodedResult = Self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventInstanceValue(contract: eventOrigin.contract, tokenContract: contractAddress, server: server, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), logIndex: Int(logIndex), filter: filterText, json: json)
    }

    private static func convertToJsonCompatible(dictionary: [String: Any]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value -> (String, Any)? in
            switch value {
            case let address as EthereumAddress:
                return (key, address.address)
            case let data as Data:
                return (key, data.hexEncoded)
            case let string as String:
                return (key, string)
            case let bigUInt as BigUInt:
                return (key, Int(bigUInt))
            default:
                //We only accept known types, otherwise serializing to JSON will crash
                return nil
            }
        })
    }

    private func formFilterFrom(fromParameter parameter: EventParameter, tokenId: TokenId, filterName: String, filterValue: String) -> (filter: [EventFilterable], textEquivalent: String)? {
        guard parameter.name == filterName else { return nil }
        guard let parameterType = SolidityType(rawValue: parameter.type) else { return nil }
        let optionalFilter: (filter: AssetAttributeValueUsableAsFunctionArguments, textEquivalent: String)?
        if let implicitAttribute = EventSourceCoordinator.convertToImplicitAttribute(string: filterValue) {
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

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        let prefix = "${"
        let suffix = "}"
        guard string.hasPrefix(prefix) && string.hasSuffix(suffix) else { return nil }
        let value = string.substring(with: prefix.count..<(string.count - suffix.count))
        return AssetImplicitAttributes(rawValue: value)
    }
}
