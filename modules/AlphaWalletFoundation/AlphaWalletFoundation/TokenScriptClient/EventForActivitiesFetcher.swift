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

    func fetchEvents(token: Token, card: TokenScriptCard, oldEventBlockNumber: Int?) async throws -> [EventActivityInstance] {
        guard let session = sessionsProvider.session(for: token.server) else {
            throw SessionTaskError(error: FetcherError.sessionNotFound)
        }

        let eventOrigin = card.eventOrigin
        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam = eventOrigin.parameters
            .filter {
                $0.isIndexed
            }
            .map {
                EventSourceForActivities.formFilterFrom(fromParameter: $0, filterName: filterName, filterValue: filterValue, wallet: session.account)
            }

        if filterParam.allSatisfy({ $0 == nil }) {
            //TODO log to console as diagnostic
            throw SessionTaskError(error: FetcherError.invalidParams)
        }

        let fromBlock: (EventFilter.Block, UInt64)
        if let blockNumber = oldEventBlockNumber {
            let value = UInt64(blockNumber + 1)
            fromBlock = (.blockNumber(value), value)
        } else {
            fromBlock = (.blockNumber(token.server.startBlock), token.server.startBlock)
        }

        let parameterFilters = filterParam.map {
            $0?.filter
        }
        let addresses = [EthereumAddress(address: eventOrigin.contract)]
        let toBlock = token.server.makeMaximumToBlockForEvents(fromBlockNumber: fromBlock.1)

        let eventFilter = EventFilter(
            fromBlock: fromBlock.0,
            toBlock: toBlock,
            addresses: addresses,
            parameterFilters: parameterFilters)

        let events = try await session.blockchainProvider.eventLogs(contractAddress: eventOrigin.contract, eventName: eventOrigin.eventName, abiString: eventOrigin.eventAbiString, filter: eventFilter)
        let results = await events.asyncCompactMap { event -> EventActivityInstance? in
            guard let blockNumber = event.eventLog?.blockNumber else { return nil }; do {
                let block = try await session.blockchainProvider.block(by: blockNumber)
                return EventSourceForActivities.convertEventToDatabaseObject(event, date: block.timestamp, filterParam: filterParam, eventOrigin: eventOrigin, tokenContract: token.contractAddress, server: token.server)
            } catch {
                logError(error, rpcServer: token.server, address: token.contractAddress)
                return nil
            }
        }
        return results
    }
}