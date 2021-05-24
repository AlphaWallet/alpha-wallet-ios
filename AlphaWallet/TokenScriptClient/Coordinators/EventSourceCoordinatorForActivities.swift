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
    private let queue = DispatchQueue(label: "com.EventSourceCoordinatorForActivities.updateQueue")
    weak var delegate: EventSourceCoordinatorForActivitiesDelegate?
    private let timestampCoordinator = GetBlockTimestampCoordinator()
    private var hasNotifyDelegateToLoadAtLeastOnce = false

    init(wallet: Wallet, config: Config, tokensStorages: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsActivityDataStoreProtocol) {
        self.wallet = wallet
        self.config = config
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    func fetchEvents(forToken token: TokenObject) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: token.contractAddress, tokenType: token.type, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards.compactMap {
            self.fetchEvents(tokenContract: token.contractAddress, server: token.server, card: $0)
        }
    }

    func fetchEvents(contract: AlphaWallet.Address, tokenType: TokenType, rpcServer: RPCServer) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: contract, tokenType: tokenType, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards.compactMap {
            fetchEvents(tokenContract: contract, server: rpcServer, card: $0)
        }
    }

    func fetchEthereumEvents() {
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(name: "Poll Ethereum events for Activities", limit: 60, autoRun: true) { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.queue.async {
                    strongSelf.fetchEthereumEventsImpl()
                }
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func fetchEthereumEventsImpl() {
        guard !isFetching else { return }
        isFetching = true

        let promises = firstly {
            tokensForEnabledRPCServers()
        }.map(on: queue, { data -> [Promise<Void>] in
            data.flatMap { data in
                self.fetchEvents(contract: data.contract, tokenType: data.tokenType, rpcServer: data.server)
            }
        })

        when(resolved: promises).done(on: queue, { _ in
            self.isFetching = false
        })
    }

    typealias EnabledTokenAddreses = [(contract: AlphaWallet.Address, tokenType: TokenType, server: RPCServer)]
    private func tokensForEnabledRPCServers() -> Promise<EnabledTokenAddreses> {
        return Promise { seal in
            let tokensStoragesForEnabledServers = self.config.enabledServers.map { self.tokensStorages[$0] }

            let data = tokensStoragesForEnabledServers.flatMap {
                $0.enabledObject
            }.compactMap {
                (contract: $0.contractAddress, tokenType: $0.type, server: $0.server)
            }

            seal.fulfill(data)
        }
    }

    private func fetchEvents(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard) -> Promise<Void>? {
        let eventOrigin = card.eventOrigin
        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam = eventOrigin.parameters.filter {
            $0.isIndexed
        }.map {
            self.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue)
        }

        if filterParam.allSatisfy({ $0 == nil }) {
            //TODO log to console as diagnostic
            return nil
        }

        return eventsDataStore.getMatchingEventsSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: tokenContract, server: server, eventName: eventOrigin.eventName).map(on: queue, { oldEvent -> EventFilter.Block in
            if let newestEvent = oldEvent {
                return .blockNumber(UInt64(newestEvent.blockNumber + 1))
            } else {
                return .blockNumber(0)
            }
        }).map(on: queue, { fromBlock -> EventFilter in
            let parameterFilters = filterParam.map { $0?.filter }
            let addresses = [EthereumAddress(address: eventOrigin.contract)]

            return EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: addresses, parameterFilters: parameterFilters)
        }).then(on: queue, { eventFilter in
            return getEventLogs(withServer: server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: self.queue)
        }).thenMap(on: queue, { event -> Promise<(EventParserResultProtocol, Date)?> in
            guard let blockNumber = event.eventLog?.blockNumber else { return .value(nil) }
            return self.timestampCoordinator.getBlockTimestamp(blockNumber, onServer: server).map(on: self.queue, { date in (event, date) })
        }).compactMapValues(on: queue, {
            $0
        }).compactMapValues(on: queue, { event, date in
            self.convertEventToDatabaseObject(event, date: date, filterParam: filterParam, eventOrigin: eventOrigin, tokenContract: tokenContract, server: server)
        }).then(on: queue, { events -> Promise<Bool> in
            return self.eventsDataStore.add(events: events, forTokenContract: tokenContract).map { _ -> Bool in
                !events.isEmpty
            }
        }).map(on: queue, { shouldNotify in
            if self.hasNotifyDelegateToLoadAtLeastOnce {
                guard shouldNotify else { return }
                self.delegate?.didUpdate(inCoordinator: self)
            } else {
                self.hasNotifyDelegateToLoadAtLeastOnce = true
                self.delegate?.didUpdate(inCoordinator: self)
            }
        })
    }

    private func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, tokenContract: AlphaWallet.Address, server: RPCServer) -> EventActivityInstance? {
        guard let blockNumber = event.eventLog?.blockNumber else { return nil }
        guard let logIndex = event.eventLog?.logIndex else { return nil }
        guard let transactionHash = event.eventLog?.transactionHash else { return nil }
        guard let transactionIndex = event.eventLog?.transactionIndex else { return nil }
        let transactionId = transactionHash.hexEncoded
        let decodedResult = Self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventActivityInstance(contract: eventOrigin.contract, tokenContract: tokenContract, server: server, date: date, eventName: eventOrigin.eventName, blockNumber: Int(blockNumber), transactionId: transactionId, transactionIndex: Int(transactionIndex), logIndex: Int(logIndex), filter: filterText, json: json)
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
            optionalFilter = nil
        }
        guard let (filterValue, textEquivalent) = optionalFilter else { return nil }
        guard let filterValueTypedForEventFilters = filterValue.coerceToArgumentTypeForEventFilter(parameterType) else { return nil }
        return (filter: [filterValueTypedForEventFilters], textEquivalent: textEquivalent)
    }

    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        EventSourceCoordinator.convertToImplicitAttribute(string: string)
    }
}
