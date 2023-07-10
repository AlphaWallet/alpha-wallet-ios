//
//  EventForActivitiesFetcher.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.10.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletTokenScript
import AlphaWalletWeb3
import BigInt

final class EventForActivitiesFetcher {
    enum FetcherError: Error {
        case invalidParams
        case sessionNotFound
    }
    private let sessionsProvider: SessionsProvider

    init(sessionsProvider: SessionsProvider) {
        self.sessionsProvider = sessionsProvider
    }

    func fetchEvents(token: Token, card: TokenScriptCard, oldEventBlockNumber: Int?) -> AnyPublisher<[EventActivityInstance], SessionTaskError> {
        Just(token)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [sessionsProvider] token -> AnyPublisher<[EventActivityInstance], SessionTaskError> in
                guard let session = sessionsProvider.session(for: token.server) else {
                    return .fail(SessionTaskError(error: FetcherError.sessionNotFound))
                }

                let eventOrigin = card.eventOrigin
                let (filterName, filterValue) = eventOrigin.eventFilter
                let filterParam = eventOrigin.parameters
                    .filter { $0.isIndexed }
                    .map { EventSourceForActivities.functional.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: session.account) }

                if filterParam.allSatisfy({ $0 == nil }) {
                    //TODO log to console as diagnostic
                    return .fail(SessionTaskError(error: FetcherError.invalidParams))
                }

                let fromBlock: (EventFilter.Block, UInt64)
                if let blockNumber = oldEventBlockNumber {
                    let value = UInt64(blockNumber + 1)
                    fromBlock = (.blockNumber(value), value)
                } else {
                    fromBlock = (.blockNumber(token.server.startBlock), token.server.startBlock)
                }

                let parameterFilters = filterParam.map { $0?.filter }
                let addresses = [EthereumAddress(address: eventOrigin.contract)]
                let toBlock = token.server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)

                let eventFilter = EventFilter(
                    fromBlock: fromBlock.0,
                    toBlock: toBlock,
                    addresses: addresses,
                    parameterFilters: parameterFilters)

                return session.blockchainProvider
                    .eventLogs(
                        contractAddress: eventOrigin.contract,
                        eventName: eventOrigin.eventName,
                        abiString: eventOrigin.eventAbiString,
                        filter: eventFilter)
                    .flatMap { events -> AnyPublisher<[EventActivityInstance], SessionTaskError> in
                        let publishers = events.compactMap { event -> AnyPublisher<EventActivityInstance?, Never> in
                            guard let blockNumber = event.eventLog?.blockNumber else {
                                return .just(nil)
                            }
                            return session.blockchainProvider.block(by: blockNumber)
                                .map { block in
                                    EventSourceForActivities.functional.convertEventToDatabaseObject(
                                        event,
                                        date: block.timestamp,
                                        filterParam: filterParam,
                                        eventOrigin: eventOrigin,
                                        tokenContract: token.contractAddress,
                                        server: token.server)
                                }.replaceError(with: nil)
                                .eraseToAnyPublisher()
                        }

                        return Publishers.MergeMany(publishers)
                            .collect()
                            .map { $0.compactMap { $0 } }
                            .setFailureType(to: SessionTaskError.self)
                            .eraseToAnyPublisher()

                    }.handleEvents(receiveCompletion: { result in
                        guard case .failure(let e) = result else { return }

                        logError(e, rpcServer: token.server, address: token.contractAddress)
                    }).eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}
