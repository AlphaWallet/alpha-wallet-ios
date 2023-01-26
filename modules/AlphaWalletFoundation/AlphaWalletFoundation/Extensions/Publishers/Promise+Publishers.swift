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
            cancellable = self
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

enum AsyncError: Error {
    case finishedWithoutValue
}

extension Publisher {

    public func sinkFirst(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in }, receiveValue: @escaping (Output) -> Void = { _ in }) {
        var cancellable: AnyCancellable?
        cancellable = self
            .first()
            .sink { result in
                receiveCompletion(result)
                cancellable = nil
            } receiveValue: { value in
                receiveValue(value)
            }
    }

    public func sinkAsync(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in }, receiveValue: @escaping (Output) -> Void = { _ in }) {
        var cancellable: AnyCancellable?
        cancellable = self
            .handleEvents(receiveCancel: { cancellable = nil })
            .sink { result in
                receiveCompletion(result)
                cancellable = nil
            } receiveValue: { value in
                receiveValue(value)
            }
    }

    public func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        if finishedWithoutValue {
                            continuation.resume(throwing: AsyncError.finishedWithoutValue)
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    finishedWithoutValue = false
                    continuation.resume(with: .success(value))
                }
        }
    }
}
