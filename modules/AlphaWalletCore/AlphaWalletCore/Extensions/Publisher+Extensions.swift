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
