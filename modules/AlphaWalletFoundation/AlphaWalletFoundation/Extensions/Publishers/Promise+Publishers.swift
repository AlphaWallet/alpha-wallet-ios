//
//  Promise+Publishers.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import PromiseKit
import Combine
import AlphaWalletCore

extension Promise {
    public func publisher(queue: DispatchQueue = .main) -> AnyPublisher<T, PromiseError> {
        var isCanceled: Bool = false
        let publisher = Deferred {
            Future<T, PromiseError> { seal in
                guard !isCanceled else { return }
                self.done(on: queue, { value in
                    seal(.success((value)))
                }).catch(on: queue, { error in
                    seal(.failure(.some(error: error)))
                })
            }
        }.handleEvents(receiveCancel: {
            isCanceled = true
        })

        return publisher
            .eraseToAnyPublisher()
    }
}

extension AnyPublisher {
    public func promise() -> Promise<Output> {
        var cancellable: AnyCancellable?
        return Promise<Output> { seal in
            cancellable = self.print("xxx.bridge to promise")
                .receive(on: RunLoop.main)
                .sink { result in
                    if case .failure(let error) = result {
                        seal.reject(error)
                    }
                    cancellable = nil
                } receiveValue: {
                    seal.fulfill($0)
                }
        }
    }
}
