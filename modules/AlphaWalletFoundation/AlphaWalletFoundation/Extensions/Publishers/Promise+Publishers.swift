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
    public var publisher: AnyPublisher<T, PromiseError> {
        var isCanceled: Bool = false
        let publisher = Deferred {
            Future<T, PromiseError> { seal in
                guard !isCanceled else { return }
                let queue = DispatchQueue.global(qos: .userInitiated)

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
