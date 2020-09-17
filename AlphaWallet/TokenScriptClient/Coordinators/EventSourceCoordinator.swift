// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

//TODO rename this generic name to reflect that it's for event instances, not for event activity
class EventSourceCoordinator {
    private var wallet: Wallet
    private let config: Config
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?

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
            let tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: wallet, sourceFromEvents: false)
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
                self?.fetchEthereumEventsImpl()
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    func fetchEthereumEventsImpl() {
        guard !isFetching else { return }
        isFetching = true
        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        var fetchPromises = [Promise<Void>]()
        for eachTokenStorage in tokensStoragesForEnabledServers {
            for eachToken in eachTokenStorage.enabledObject {
                let promises = fetchEventsByTokenId(forToken: eachToken)
                fetchPromises.append(contentsOf: promises)
            }
        }
        when(resolved: fetchPromises).done { _ in
            self.isFetching = false
        }
    }

    private func fetchEvents(forTokenId tokenId: TokenId, token: TokenObject, eventOrigin: EventOrigin) -> Promise<Void> {
        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam: [(filter: [EventFilterable], textEquivalent: String)?] = eventOrigin.parameters
                .filter { $0.isIndexed }
                .map { self.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue) }
        let fromBlock: EventFilter.Block
        let oldEvents = eventsDataStore.getMatchingEventsSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
        if let newestEvent = oldEvents.last {
            fromBlock = .blockNumber(UInt64(newestEvent.blockNumber + 1))
        } else {
            fromBlock = .blockNumber(0)
        }
        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: [EthereumAddress(address: eventOrigin.contract)], parameterFilters: filterParam.map { $0?.filter })
        return firstly {
            getEventLogs(withServer: token.server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
        }.map { result -> [EventInstance] in
            result.compactMap { self.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, token: token, server: token.server) }
        }.map { events in
            self.eventsDataStore.add(events: events, forTokenContract: token.contractAddress)
        }
    }

    private func convertEventToDatabaseObject(_ event: EventParserResultProtocol, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, token: TokenObject, server: RPCServer) -> EventInstance? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        let decodedResult = self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"
        return EventInstance(contract: eventOrigin.contract, tokenContract: token.contractAddress, server: server, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), logIndex: Int(logIndex), filter: filterText, json: json)
    }

    private func convertToJsonCompatible(dictionary: [String: Any]) -> [String: Any] {
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
