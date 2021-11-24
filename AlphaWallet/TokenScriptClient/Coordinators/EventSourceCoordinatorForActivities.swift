// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

protocol EventSourceCoordinatorForActivitiesType: AnyObject {
    func fetchEvents(forToken token: TokenObject) -> [Promise<Void>]
    func fetchEvents(contract: AlphaWallet.Address, tokenType: TokenType, rpcServer: RPCServer) -> [Promise<Void>]
    func fetchEthereumEvents()
}

class EventSourceCoordinatorForActivities: EventSourceCoordinatorForActivitiesType {
    private var wallet: Wallet
    private let config: Config
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.EventSourceCoordinatorForActivities.updateQueue")

    init(wallet: Wallet, config: Config, tokenCollection: TokenCollection, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsActivityDataStoreProtocol) {
        self.wallet = wallet
        self.config = config
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    func fetchEvents(forToken token: TokenObject) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: token.contractAddress, tokenType: token.type, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards.compactMap {
            EventSourceCoordinatorForActivities.functional.fetchEvents(tokenContract: token.contractAddress, server: token.server, card: $0, eventsDataStore: eventsDataStore, queue: queue, wallet: wallet)
        }
    }

    func fetchEvents(contract: AlphaWallet.Address, tokenType: TokenType, rpcServer: RPCServer) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: contract, tokenType: tokenType, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards.compactMap {
            EventSourceCoordinatorForActivities.functional.fetchEvents(tokenContract: contract, server: rpcServer, card: $0, eventsDataStore: eventsDataStore, queue: queue, wallet: wallet)
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
            return data.flatMap { [weak self] data -> [Promise<Void>] in
                guard let strongSelf = self else { return [] }
                return strongSelf.fetchEvents(contract: data.contract, tokenType: data.tokenType, rpcServer: data.server)
            }
        })

        when(resolved: promises).done(on: queue, { [weak self] _ in
            self?.isFetching = false
        })
    }

    typealias EnabledTokenAddreses = [(contract: AlphaWallet.Address, tokenType: TokenType, server: RPCServer)]
    private func tokensForEnabledRPCServers() -> Promise<EnabledTokenAddreses> {
        tokenCollection.tokenObjects.map { tokenObjects -> EnabledTokenAddreses in
            tokenObjects.compactMap { (contract: $0.contractAddress, tokenType: $0.type, server: $0.server) }
        }
    }
}

extension EventSourceCoordinatorForActivities {
    class functional {}
}

extension EventSourceCoordinatorForActivities.functional {
    static func fetchEvents(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, eventsDataStore: EventsActivityDataStoreProtocol, queue: DispatchQueue, wallet: Wallet) -> Promise<Void>? {
        return Promise { seal in
            queue.async {
                let eventOrigin = card.eventOrigin
                let (filterName, filterValue) = eventOrigin.eventFilter
                let filterParam = eventOrigin.parameters.filter {
                    $0.isIndexed
                }.map {
                    EventSourceCoordinatorForActivities.functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: wallet)
                }

                if filterParam.allSatisfy({ $0 == nil }) {
                    //TODO log to console as diagnostic
                    seal.fulfill(())
                    return
                }

                eventsDataStore.getMatchingEventsSortedByBlockNumber(forContract: eventOrigin.contract, tokenContract: tokenContract, server: server, eventName: eventOrigin.eventName).map(on: queue, { oldEvent -> (EventFilter.Block, UInt64) in
                    if let newestEvent = oldEvent {
                        let value = UInt64(newestEvent.blockNumber + 1)
                        return (.blockNumber(value), value)
                    } else {
                        return (.blockNumber(0), 0)
                    }
                }).map(on: queue, { fromBlock -> EventFilter in
                    let parameterFilters = filterParam.map { $0?.filter }
                    let addresses = [EthereumAddress(address: eventOrigin.contract)]
                    let toBlock = server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)
                    return EventFilter(fromBlock: fromBlock.0, toBlock: toBlock, addresses: addresses, parameterFilters: parameterFilters)
                }).then(on: queue, { eventFilter in
                    getEventLogs(withServer: server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter, queue: queue)
                }).then(on: queue, { events -> Promise<[EventActivityInstance]> in
                    let promises = events.compactMap { event -> Promise<EventActivityInstance?> in
                        guard let blockNumber = event.eventLog?.blockNumber else {
                            return .value(nil)
                        }

                        return GetBlockTimestampCoordinator()
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
                }).then(on: queue, { events -> Promise<Void> in
                    if events.isEmpty {
                        return .value(())
                    } else {
                        return eventsDataStore.add(events: events, forTokenContract: tokenContract).then(on: queue, { _ -> Promise<Void> in
                            return .value(())
                        })
                    }
                }).done { _ in
                    seal.fulfill(())
// swiftlint:disable closure_end_indentation
                }.catch { e in
// swiftlint:enable closure_end_indentation
                    error(value: e, rpcServer: server, address: tokenContract)
                    seal.reject(e)
                }
            }
        }
    }

    private static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, tokenContract: AlphaWallet.Address, server: RPCServer) -> EventActivityInstance? {
        guard let eventLog = event.eventLog else { return nil }

        let transactionId = eventLog.transactionHash.hexEncoded
        let decodedResult = EventSourceCoordinator.functional.convertToJsonCompatible(dictionary: event.decodedResult)
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
        if let implicitAttribute = EventSourceCoordinator.functional.convertToImplicitAttribute(string: filterValue) {
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
