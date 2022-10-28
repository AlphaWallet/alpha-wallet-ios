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
    private let getEventLogs: GetEventLogs
    private let queue: DispatchQueue = .global()
    private let wallet: Wallet
    private let analytics: AnalyticsLogger
    private lazy var getBlockTimestamp = GetBlockTimestamp(analytics: analytics)

    init(getEventLogs: GetEventLogs, wallet: Wallet, analytics: AnalyticsLogger) {
        self.getEventLogs = getEventLogs
        self.wallet = wallet
        self.analytics = analytics
    }

    func fetchEvents(token: Token, card: TokenScriptCard, oldEvent: EventActivityInstance?) -> Promise<[EventActivityInstance]> {
        firstly {
            .value(token)
        }.then(on: queue, { [queue, getEventLogs, wallet, getBlockTimestamp] token -> Promise<[EventActivityInstance]> in
            let eventOrigin = card.eventOrigin
            let (filterName, filterValue) = eventOrigin.eventFilter
            let filterParam = eventOrigin.parameters
                .filter { $0.isIndexed }
                .map { EventSourceForActivities.functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: wallet) }

            if filterParam.allSatisfy({ $0 == nil }) {
                //TODO log to console as diagnostic
                return .init(error: PMKError.cancelled)
            }

            let fromBlock: (EventFilter.Block, UInt64)
            if let newestEvent = oldEvent {
                let value = UInt64(newestEvent.blockNumber + 1)
                fromBlock = (.blockNumber(value), value)
            } else {
                fromBlock = (.blockNumber(0), 0)
            }
            let parameterFilters = filterParam.map { $0?.filter }
            let addresses = [EthereumAddress(address: eventOrigin.contract)]
            let toBlock = token.server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)
            let eventFilter = EventFilter(fromBlock: fromBlock.0, toBlock: toBlock, addresses: addresses, parameterFilters: parameterFilters)

            return getEventLogs
                .getEventLogs(contractAddress: eventOrigin.contract, server: token.server, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
                .then(on: queue, { [queue] events -> Promise<[EventActivityInstance]> in
                    let promises = events.compactMap { event -> Promise<EventActivityInstance?> in
                        guard let blockNumber = event.eventLog?.blockNumber else {
                            return .value(nil)
                        }

                        return getBlockTimestamp
                            .getBlockTimestamp(for: blockNumber, server: token.server)
                            .map(on: queue, { date in
                                EventSourceForActivities.functional.convertEventToDatabaseObject(event, date: date, filterParam: filterParam, eventOrigin: eventOrigin, tokenContract: token.contractAddress, server: token.server)
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
