//
//  EventForActivitiesFetcher.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.10.2022.
//

import Foundation
import AlphaWalletCore
import BigInt
import PromiseKit
import Combine
import AlphaWalletWeb3

final class EventForActivitiesFetcher {
    private let queue: DispatchQueue = .global()
    private let sessionsProvider: SessionsProvider

    init(sessionsProvider: SessionsProvider) {
        self.sessionsProvider = sessionsProvider
    }

    func fetchEvents(token: Token, card: TokenScriptCard, oldEventBlockNumber: Int?) -> Promise<[EventActivityInstance]> {
        firstly {
            .value(token)
        }.then(on: queue, { [queue, sessionsProvider] token -> Promise<[EventActivityInstance]> in
            guard let session = sessionsProvider.session(for: token.server) else {
                return .init(error: PMKError.cancelled)
            }

            let eventOrigin = card.eventOrigin
            let (filterName, filterValue) = eventOrigin.eventFilter
            let filterParam = eventOrigin.parameters
                .filter { $0.isIndexed }
                .map { EventSourceForActivities.functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: session.account) }

            if filterParam.allSatisfy({ $0 == nil }) {
                //TODO log to console as diagnostic
                return .init(error: PMKError.cancelled)
            }

            let fromBlock: (EventFilter.Block, UInt64)
            if let blockNumber = oldEventBlockNumber {
                let value = UInt64(blockNumber + 1)
                fromBlock = (.blockNumber(value), value)
            } else {
                fromBlock = (.blockNumber(0), 0)
            }
            let parameterFilters = filterParam.map { $0?.filter }
            let addresses = [EthereumAddress(address: eventOrigin.contract)]
            let toBlock = token.server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)
            let eventFilter = EventFilter(fromBlock: fromBlock.0, toBlock: toBlock, addresses: addresses, parameterFilters: parameterFilters)

            return session.blockchainProvider
                .eventLogsPromise(contractAddress: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
                .then(on: queue, { [queue] events -> Promise<[EventActivityInstance]> in
                    let promises = events.compactMap { event -> Promise<EventActivityInstance?> in
                        guard let blockchainProvider = sessionsProvider.session(for: token.server)?.blockchainProvider, let blockNumber = event.eventLog?.blockNumber else {
                            return .value(nil)
                        }

                        return session.blockchainProvider
                            .blockByNumberPromise(blockNumber: blockNumber)
                            .map(on: queue, { block in
                                EventSourceForActivities.functional.convertEventToDatabaseObject(
                                    event,
                                    date: block.timestamp,
                                    filterParam: filterParam,
                                    eventOrigin: eventOrigin,
                                    tokenContract: token.contractAddress,
                                    server: token.server)

                            }).recover(on: queue, { _ -> Promise<EventActivityInstance?> in
                                return .value(nil)
                            })
                    }

                    return when(resolved: promises)
                        .map(on: queue, { $0.compactMap { $0.optionalValue }.compactMap { $0 } })

                }).recover(on: queue, { e -> Promise<[EventActivityInstance]> in
                    logError(e, rpcServer: token.server, address: token.contractAddress)
                    throw e
                })
        })
    }
}
