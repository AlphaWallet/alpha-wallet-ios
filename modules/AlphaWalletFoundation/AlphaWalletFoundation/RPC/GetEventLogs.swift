//
//  GetEventLogs.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 30.05.2023.
//

import Foundation
import AlphaWalletLogger
import AlphaWalletWeb3
import AlphaWalletCore
import Combine

final class GetEventLogs {
    typealias Publisher = AnyPublisher<[EventParserResultProtocol], SessionTaskError>

    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth.getEventLogs", qos: .utility)
    private var inFlightPublishers: [String: Publisher] = [:]
    private let web3: Web3?

    init(server: RPCServer) {
        web3 = try? Web3.instance(for: server, timeout: 60)
    }
    func clean() {
        inFlightPublishers.removeAll()
    }

    func getEventLogs(contractAddress: AlphaWallet.Address,
                      server: RPCServer,
                      eventName: String,
                      abiString: String,
                      filter: EventFilter) -> Publisher {

            //It is fine to use the default String representation of `EventFilter` in the cache key. But it is crucial to include it, because the actual variables of the event log fetching are in there. For example ERC1155's `TransferSingle` event is used for fetching both send and receive single token ID events. We can ony tell based on the arguments in `EventFilter` whether it is a send or receive
        let key = Self.generateEventLogCachingKey(
            contractAddress: contractAddress,
            server: server,
            eventName: eventName,
            abiString: abiString,
            filter: filter)

        return Just(key)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue] key -> Publisher in
                guard let web3 = self?.web3 else { return .empty() }

                if let publisher = self?.inFlightPublishers[key] {
                    return publisher
                } else {

                    let publisher = Just(web3)
                        .setFailureType(to: PromiseError.self)
                        .tryMap { try Web3.Contract(web3: $0, abiString: abiString, at: EthereumAddress(address: contractAddress), options: $0.options) }
                        .mapError { return PromiseError(error: $0) }
                        .flatMap { $0.getIndexedEventsPromise(eventName: eventName, filter: filter).publisher(queue: queue) }
                        .mapError { SessionTaskError(error: $0.embedded) }
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in self?.inFlightPublishers[key] = nil })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.handleEvents(receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                warnLog("[eth_getLogs] failure for server: \(server) with error: \(error)")
            }).eraseToAnyPublisher()
    }

    //Exposed for testing
    static func generateEventLogCachingKey(contractAddress: AlphaWallet.Address, server: RPCServer, eventName: String, abiString: String, filter: EventFilter) -> String {
        "\(contractAddress.eip55String)-\(server.chainID)-\(eventName)-\(abiString)-\(filter)"
    }
}
