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
        var strongSelf: Promise? = self

        let publisher = Deferred {
            Future<T, PromiseError> { seal in
                strongSelf?.done(on: queue, { value in
                    seal(.success((value)))
                }).catch(on: queue, { error in
                    seal(.failure(.some(error: error)))
                }).finally(on: queue, {
                    strongSelf = nil
                })
            }
        }.handleEvents(receiveCancel: {
            strongSelf = nil
        })

        return publisher.eraseToAnyPublisher()
    }
}

enum AsyncError: Error {
    case valueWasNotEmittedBeforeCompletion
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
}

private class CancellableWrapper {
    var cancellable: AnyCancellable?
}

extension Publisher {

    public var values: AsyncThrowingStream<Output, Error> {
        return AsyncThrowingStream(Output.self) { continuation in
            let cancellable = sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }, receiveValue: { output in
                continuation.yield(output)
            })

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public var first: Output {
        get async throws {
            var didSendValue: Bool = false
            let cancellableWrapper = CancellableWrapper()
            return try await withTaskCancellationHandler {
                cancellableWrapper.cancellable?.cancel()
            } operation: {
                try Task.checkCancellation()

                return try await withUnsafeThrowingContinuation { continuation in
                    guard !Task.isCancelled else {
                        continuation.resume(throwing: Task.CancellationError())
                        return
                    }

                    cancellableWrapper.cancellable =
                    handleEvents(receiveCancel: {
                        continuation.resume(throwing: Task.CancellationError())
                    }).sink { completion in
                        if case let .failure(error) = completion {
                            continuation.resume(throwing: error)
                        } else if !didSendValue {
                            continuation.resume(throwing: AsyncError.valueWasNotEmittedBeforeCompletion)
                        }
                    } receiveValue: { value in
                        continuation.resume(with: .success(value))
                        didSendValue = true
                    }
                }
            }
        }
    }
}

//TODO: this exist for migration from `Promise`/`Future` to async-await. We can remove this once all usage have been migrated.
public extension Promise {
    convenience init(operation: @escaping () async throws -> T) {
        self.init { seal in
            Task {
                do {
                    let output = try await operation()
                    seal.fulfill(output)
                } catch {
                    seal.reject(error)
                }
            }
        }
    }
}

public extension Future where Failure == Error {
    convenience init(operation: @escaping () async throws -> Output) {
        self.init { promise in
            Task {
                do {
                    let output = try await operation()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
}
