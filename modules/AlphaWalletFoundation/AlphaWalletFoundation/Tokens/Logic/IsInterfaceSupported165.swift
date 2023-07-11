//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletWeb3

public class IsInterfaceSupported165 {
    private let fileName: String
    private let queue = DispatchQueue(label: "org.alphawallet.swift.isInterfaceSupported165")
    private lazy var storage: Storage<[String: Bool]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: AnyPublisher<Bool, SessionTaskError>] = [:]

    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider, fileName: String = "isInterfaceSupported165") {
        self.blockchainProvider = blockchainProvider
        self.fileName = fileName
    }

    public func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, SessionTaskError> {
        return Just(hash)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, blockchainProvider, storage] hash -> AnyPublisher<Bool, SessionTaskError> in
                let key = "\(hash)-\(contract)-\(blockchainProvider.server)"

                if let value = storage.value[key] {
                    return .just(value)
                }

                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    let promise = blockchainProvider
                        .call(Erc20SupportsInterfaceMethodCall(contract: contract, hash: hash))
                        .receive(on: queue)
                        .handleEvents(receiveOutput: { supported in
                            storage.value[key] = supported
                        }, receiveCompletion: { _ in
                            self?.inFlightPromises[key] = .none
                        })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }
}
