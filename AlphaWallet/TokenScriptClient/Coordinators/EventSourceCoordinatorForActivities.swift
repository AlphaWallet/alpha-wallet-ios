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
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsActivityDataStoreProtocol
    private var isFetching = false
    private var rateLimitedUpdater: RateLimiter?
    private let queue = DispatchQueue(label: "com.EventSourceCoordinatorForActivities.updateQueue")

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
            self.fetchEvents(tokenContract: token.contractAddress, server: token.server, card: $0, queue: queue, eventsDataStore: eventsDataStore)
        }
    }

    func fetchEvents(contract: AlphaWallet.Address, tokenType: TokenType, rpcServer: RPCServer) -> [Promise<Void>] {
        let xmlHandler = XMLHandler(contract: contract, tokenType: tokenType, assetDefinitionStore: assetDefinitionStore)
        guard xmlHandler.hasAssetDefinition else { return [] }
        return xmlHandler.activityCards.compactMap {
            fetchEvents(tokenContract: contract, server: rpcServer, card: $0, queue: queue, eventsDataStore: eventsDataStore)
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
            tokensForEnabledRPCServers(config: config, tokensStorages: tokensStorages)
        }.map(on: queue, { data -> [Promise<Void>] in
            data.flatMap { data in
                self.fetchEvents(contract: data.contract, tokenType: data.tokenType, rpcServer: data.server)
            }
        })

        when(resolved: promises).done(on: queue, { [weak self] _ in
            self?.isFetching = false
        })
    }

    typealias EnabledTokenAddreses = [(contract: AlphaWallet.Address, tokenType: TokenType, server: RPCServer)]
    private func tokensForEnabledRPCServers(config: Config, tokensStorages: ServerDictionary<TokensDataStore>) -> Promise<EnabledTokenAddreses> {
        return Promise { seal in
            let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }

            let data = tokensStoragesForEnabledServers.flatMap {
                $0.enabledObject
            }.compactMap {
                (contract: $0.contractAddress, tokenType: $0.type, server: $0.server)
            }

            seal.fulfill(data)
        }
    }

    private func fetchEvents(tokenContract: AlphaWallet.Address, server: RPCServer, card: TokenScriptCard, queue: DispatchQueue, eventsDataStore: EventsActivityDataStoreProtocol) -> Promise<Void>? {
        let w = wallet
        return Promise { seal in
            queue.async {

                let eventOrigin = card.eventOrigin
                let (filterName, filterValue) = eventOrigin.eventFilter
                let filterParam = eventOrigin.parameters.filter {
                    $0.isIndexed
                }.map {
                    EventSourceCoordinatorForActivities.functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: w)
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

                    let toBlock: EventFilter.Block
                    if server == .binance_smart_chain || server == .binance_smart_chain_testnet || server == .heco {
                        //NOTE: binance_smart_chain not allows range more then 5000
                        toBlock = .blockNumber(fromBlock.1 + 4000)
                    } else {
                        toBlock = .latest
                    }
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
                                EventSourceCoordinatorForActivities.functional.convertEventToDatabaseObject(event, date: date, filterParam: filterParam, eventOrigin: eventOrigin, tokenContract: tokenContract, server: server)
                            }).recover(on: queue, { _ -> Promise<EventActivityInstance?> in
                                return .value(nil)
                            })
                    }

                    return when(resolved: promises).map(on: queue, { _ -> [EventActivityInstance] in
                        promises.compactMap { $0.value }.compactMap { $0 }
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
                }.catch { e in
                    seal.reject(e)
                }
            }
        }
    }
    
    static func convertToImplicitAttribute(string: String) -> AssetImplicitAttributes? {
        EventSourceCoordinator.convertToImplicitAttribute(string: string)
    }
}

extension EventSourceCoordinatorForActivities {
    class functional {}
}

extension EventSourceCoordinatorForActivities.functional {
    static func formFilterFrom(fromParameter parameter: EventParameter, filterName: String, filterValue: String, wallet: Wallet) -> (filter: [EventFilterable], textEquivalent: String)? {
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

    static func convertEventToDatabaseObject(_ event: EventParserResultProtocol, date: Date, filterParam: [(filter: [EventFilterable], textEquivalent: String)?], eventOrigin: EventOrigin, tokenContract: AlphaWallet.Address, server: RPCServer) -> EventActivityInstance? {
        guard let eventLog = event.eventLog else { return nil }

        let transactionId = eventLog.transactionHash.hexEncoded
        let decodedResult = Self.convertToJsonCompatible(dictionary: event.decodedResult)
        guard let json = decodedResult.jsonString else { return nil }
        //TODO when TokenScript schema allows it, support more than 1 filter
        let filterTextEquivalent = filterParam.compactMap({ $0?.textEquivalent }).first
        let filterText = filterTextEquivalent ?? "\(eventOrigin.eventFilter.name)=\(eventOrigin.eventFilter.value)"

        return EventActivityInstance(contract: eventOrigin.contract, tokenContract: tokenContract, server: server, date: date, eventName: eventOrigin.eventName, blockNumber: Int(eventLog.blockNumber), transactionId: transactionId, transactionIndex: Int(eventLog.transactionIndex), logIndex: Int(eventLog.logIndex), filter: filterText, json: json)
    }
}
