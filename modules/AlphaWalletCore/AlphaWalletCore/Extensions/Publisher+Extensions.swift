//
//  Publisher+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2022.
//

import Foundation
import Combine
import PromiseKit

public extension Publisher {
    static func empty() -> AnyPublisher<Output, Failure> {
        return Empty().eraseToAnyPublisher()
    }

    static func just(_ output: Output) -> AnyPublisher<Output, Failure> {
        return Just(output)
            .setFailureType(to: Failure.self)
            .eraseToAnyPublisher()
    }

    static func fail(_ error: Failure) -> AnyPublisher<Output, Failure> {
        return Fail(error: error).eraseToAnyPublisher()
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

enum PublisherAsAsyncError: Error {
    case finishedWithoutValue
}

//TODO remove most if not all callers once we migrate completely to async-await
public extension AnyPublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        if finishedWithoutValue {
                            continuation.resume(throwing: PublisherAsAsyncError.finishedWithoutValue)
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

//TODO remove most if not all callers once we migrate completely to async-await
public func asFuture<T>(block: @escaping () async -> T) -> Future<T, Never> {
    Future<T, Never> { promise in
        Task { @MainActor in
            let result: T = await block()
            promise(.success(result))
        }
    }
}

//TODO remove most if not all callers once we migrate completely to async-await
public func asFutureThrowable<T>(block: @escaping () async throws -> T) -> Future<T, Error> {
    Future<T, Error> { promise in
        Task { @MainActor in
            do {
                let result: T = try await block()
                promise(.success(result))
            } catch {
                promise(.failure(error))
            }
        }
    }
}
