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
    private let sessionsProvider: SessionsProvider

    init(sessionsProvider: SessionsProvider) {
        self.sessionsProvider = sessionsProvider
    }

    func fetchEvents(tokenId: TokenId, token: Token, eventOrigin: EventOrigin, oldEventBlockNumber: Int?) async throws -> [EventInstanceValue] {
        guard let session = sessionsProvider.session(for: token.server) else {
            throw SessionTaskError.responseError(PMKError.cancelled)
        }

        let (filterName, filterValue) = eventOrigin.eventFilter
        let filterParam = eventOrigin
            .parameters
            .filter { $0.isIndexed }
            .map { EventSource.functional.formFilterFrom(fromParameter: $0, tokenId: tokenId, filterName: filterName, filterValue: filterValue, wallet: session.account) }

        let fromBlock: EventFilter.Block
        if let newestEvent = oldEventBlockNumber {
            fromBlock = .blockNumber(UInt64(newestEvent + 1))
        } else {
            fromBlock = .blockNumber(token.server.startBlock)
        }
        let addresses = [EthereumAddress(address: eventOrigin.contract)]
        let parameterFilters = filterParam.map { $0?.filter }

        let eventFilter = EventFilter(fromBlock: fromBlock, toBlock: .latest, addresses: addresses, parameterFilters: parameterFilters)

        do {
            let events = try await session.blockchainProvider.eventLogs(
                contractAddress: eventOrigin.contract,
                eventName: eventOrigin.eventName,
                abiString: eventOrigin.eventAbiString,
                filter: eventFilter)

            return events.compactMap {
                EventSource.functional.convertEventToDatabaseObject($0, filterParam: filterParam, eventOrigin: eventOrigin, contractAddress: token.contractAddress, server: token.server)
            }
        } catch {
            logError(error, rpcServer: token.server, address: token.contractAddress)
            throw error
        }
    }
}
