//
//  Subscribable.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2023.
//

import Foundation
import Combine

//TODO probably should have an ID which is really good for debugging
public struct Subscribable<T>: Equatable {
    public static func == (lhs: Subscribable<T>, rhs: Subscribable<T>) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    private let subject: CurrentValueSubject<T?, Never>
    private let uuid = UUID()

    public var value: T? {
        return subject.value
    }
    public var publisher: AnyPublisher<T?, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ value: T?) {
        subject = .init(value)
    }

    public func send(_ newValue: T?) {
        subject.send(newValue)
    }

    public func sinkAsync(_ subscribe: @escaping (T?) -> Void) {
        subject.sinkAsync(receiveValue: subscribe)
    }

    func sink(_ completion: @escaping (T?) -> Void) -> AnyCancellable {
        return subject.sink(receiveValue: completion)
    }

    public func sinkFirst(_ subscribe: @escaping (T) -> Void) {
        subject.compactMap { $0 }
            .first()
            .sinkAsync(receiveValue: subscribe)
    }
}
