//
//  EventFetcher.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.10.2022.
//

import Foundation
import BigInt
import PromiseKit
import Combine
import AlphaWalletWeb3

final class EventFetcher {
    private let queue: DispatchQueue = .global()
    private let sessionsProvider: SessionsProvider

    init(sessionsProvider: SessionsProvider) {
        self.sessionsProvider = sessionsProvider
    }

    func fetchEvents(tokenId: TokenId, token: Token, eventOrigin: EventOrigin, oldEventBlockNumber: Int?) -> Promise<[EventInstanceValue]> {
        firstly {
            .value(tokenId)
        }.then(on: queue, { [queue, sessionsProvider] tokenId -> Promise<[EventInstanceValue]> in
            guard let session = sessionsProvider.session(for: token.server) else { return .init(error: PMKError.cancelled) }

            let (filterName, filterValue) = eventOrigin.eventFilter
            let filterParam = eventOrigin
                .parameters
                .filter { $0.isIndexed }
                .map { EventSource.functional.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue, wallet: session.account) }

            let fromBlock: EventFilter.Block
            if let newestEvent = oldEventBlockNumber {
                fromBlock = .blockNumber(UInt64(newestEvent + 1))
            } else {
                fromBlock = .blockNumber(0)
            }
            let addresses = [EthereumAddress(address: eventOrigin.contract)]
            let parameterFilters = filterParam.map { $0?.filter }

            let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: addresses, parameterFilters: parameterFilters)

            return session.blockchainProvider
                .eventLogsPromise(contractAddress: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
                .map(on: queue, { result -> [EventInstanceValue] in
                    return result.compactMap {
                        EventSource.functional.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, contractAddress: token.contractAddress, server: token.server)
                    }
                }).recover(on: queue, { e -> Promise<[EventInstanceValue]> in
                    logError(e, rpcServer: token.server, address: token.contractAddress)
                    throw e
                })
        })
    }
}
