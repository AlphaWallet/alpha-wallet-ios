// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

protocol EventSourceCoordinatorForActivitiesDelegate: class {
    func didUpdate(inCoordinator coordinator: EventSourceCoordinatorForActivities)
}

class EventSourceCoordinatorForActivities {
    private var wallet: Wallet
    private let config: Config
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?

    weak var delegate: EventSourceCoordinatorForActivitiesDelegate?

    init(wallet: Wallet, config: Config, tokensStorages: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsActivityDataStoreProtocol) {
        self.wallet = wallet
        self.config = config
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    func fetchEvents(forToken token: TokenObject) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return .init() }
        var fetchPromises = [Promise<Void>]()
        for each in xmlHandler.activityCards {
            let promise = fetchEvents(token: token, eventOrigin: each.eventOrigin)
            fetchPromises.append(promise)
        }
        return fetchPromises
    }

    func fetchEthereumEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for Activities", limit: 15, autoRun: true) { [weak self] in
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
                //TODO fix for activities: we are hardcoding the list of tokens support for activities for performance reasons
                guard Constants.Contracts.aaveDebt.sameContract(as: eachToken.contract) || Constants.erc20ContractsSupportingActivities.contains(where: { $0.address.sameContract(as: eachToken.contract) }) else { continue }
                let promises = fetchEvents(forToken: eachToken)
                fetchPromises.append(contentsOf: promises)
            }
        }
        when(resolved: fetchPromises).done { _ in
            self.isFetching = false
        }
    }

    private func fetchEvents(token: TokenObject, eventOrigin: EventOrigin) -> Promise<Void> {
        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam: [(filter: [EventFilterable], textEquivalent: String)?] = eventOrigin.parameters
                .filter { $0.isIndexed }
                .map { self.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue) }
        let fromBlock: EventFilter.Block
        let oldEvents = eventsDataStore.getMatchingEventsSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: token.contractAddress, server: token.server, eventName: eventOrigin.eventName)
        //TODO fix for activities: have to start from 0 if the tokenscript file changes? Careful with problem with signature. But signature results aren't cached, right? Do they trigger as XML changed?
        //if let newestEvent = oldEvents.last {
        //    fromBlock = .blockNumber(UInt64(newestEvent.blockNumber + 1))
        //} else {
            fromBlock = .blockNumber(0)
        //}
        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: [EthereumAddress(address: eventOrigin.contract)], parameterFilters: filterParam.map { $0?.filter })
        return firstly {
            getEventLogs(withServer: token.server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
        }.thenMap { event -> Promise<(EventParserResultProtocol, Date)?> in
            guard let blockNumber = event.eventLog?.blockNumber else { return .value(nil) }
            return GetBlockTimestamp().getBlockTimestamp(blockNumber, onServer: token.server).map { date in (event, date) }
        }.compactMapValues {
            $0
        }.compactMapValues { event, date in
            self.convertEventToDatabaseObject(event, date: date, filterParam: filterParam, eventOrigin: eventOrigin, token: token, server: token.server)
        }.map { events in
            self.eventsDataStore.add(events: events, forTokenContract: token.contractAddress)
            self.delegate?.didUpdate(inCoordinator: self)
        }
    }

    private func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, token: TokenObject, server: RPCServer) -> EventActivity? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        guard let transactionHash = event.eventLog?.transactionHash else { return nil }
        let transactionId = transactionHash.hexEncoded
        let decodedResult = self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"
        return EventActivity(contract: eventOrigin.contract, tokenContract: token.contractAddress, server: server, date: date, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), transactionId: transactionId, logIndex: Int(logIndex), filter: filterText, json: json)
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
                //Must not do `Int(bigUInt)` because it crashes upon overflow
                return (key, String(bigUInt))
            default:
                //We only accept known types, otherwise serializing to JSON will crash
                return nil
            }
        })
    }

    private func formFilterFrom(fromParameter parameter: EventParameter, filterName: String, filterValue: String) -> (filter: [EventFilterable], textEquivalent: String)? {
        guard parameter.name == filterName else { return nil }
        guard let parameterType = SolidityType(rawValue: parameter.type) else { return nil }
        let optionalFilter: (filter: AssetAttributeValueUsableAsFunctionArguments, textEquivalent: String)?
        if let implicitAttribute = EventSourceCoordinatorForActivities.convertToImplicitAttribute(string: filterValue) {
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
            optionalFilter = (filter: .string(filterValue), textEquivalent: "\(filterName)=\(filterValue)")
        }
        guard let (filterValue, textEquivalent) = optionalFilter else { return nil }
        guard let filterValueTypedForEventFilters = filterValue.coerceToArgumentTypeForEventFilter(parameterType) else { return nil }
        return (filter: [filterValueTypedForEventFilters], textEquivalent: textEquivalent)
    }

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        EventSourceCoordinator.convertToImplicitAttribute(string: string)
    }
}
