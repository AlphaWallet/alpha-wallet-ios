//
//  Publisher+Utils.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2022.
//

import Foundation
import Combine

public extension Publisher {

//    The flatMapLatest operator behaves much like the standard FlatMap operator, except that whenever
//    a new item is emitted by the source Publisher, it will unsubscribe to and stop mirroring the Publisher
//    that was generated from the previously-emitted item, and begin only mirroring the current one.
    public func flatMapLatest<T: Publisher>(_ transform: @escaping (Self.Output) -> T) -> Publishers.SwitchToLatest<T, Publishers.Map<Self, T>> where T.Failure == Self.Failure {
        map(transform).switchToLatest()
    }

    public static func empty() -> AnyPublisher<Output, Failure> {
        return Empty().eraseToAnyPublisher()
    }

    public static func just(_ output: Output) -> AnyPublisher<Output, Failure> {
        return Just(output)
            .setFailureType(to: Failure.self)
            .eraseToAnyPublisher()
    }

    public static func fail(_ error: Failure) -> AnyPublisher<Output, Failure> {
        return Fail(error: error).eraseToAnyPublisher()
    }

    public func unwrap<T>() -> Publishers.CompactMap<Self, T> where Output == T? {
        compactMap { $0 }
    }

    public func mapToVoid() -> AnyPublisher<Void, Failure> {
        map { _ in }.eraseToAnyPublisher()
    }
}
