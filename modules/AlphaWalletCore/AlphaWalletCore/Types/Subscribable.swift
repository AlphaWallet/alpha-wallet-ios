//
//  Subscribable.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2023.
//

import Foundation
import Combine

//TODO: probably should have an ID which is really good for debugging
public struct Subscribable<T>: Equatable {
    typealias Subject = CurrentValueSubject<Loadable<T?, Never>, Never>

    public static func == (lhs: Subscribable<T>, rhs: Subscribable<T>) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    private let subject: Subject
    private let uuid = UUID()

    public var value: T? {
        return subject.value.value?.flatMap { $0 }
    }

    public var publisher: AnyPublisher<T?, Never> {
        subject.compactMap { $0.value }
            .eraseToAnyPublisher()
    }

    public init(value: T?) {
        subject = .init(.done(value))
    }

    public init() {
        subject = .init(.loading)
    }

    public func send(_ newValue: T?) {
        subject.send(.done(newValue))
    }

    public func mapFirst<V>(_ closure: @escaping (T?) -> V?) -> Subscribable<V> {
        let new = Subscribable<V>()
        var subject: CurrentValueSubject<Loadable<V?, Never>, Never>? = new.subject

        subject?.cancellable = publisher
            .first()
            .map(closure)
            .map { Loadable<V?, Never>.done($0) }
            .sink(receiveCompletion: { result in
                subject?.send(completion: result)

                subject?.cancellable?.cancel()
                subject = nil
            }, receiveValue: { value in
                subject?.send(value)
            })

        return new
    }

    public func send(completion: Subscribers.Completion<Never>) {
        subject.send(completion: completion)
    }
}

private var subjectCancellableKey: Void?
extension CurrentValueSubject {

    fileprivate var cancellable: Cancellable? {
      get { objc_getAssociatedObject(self, &subjectCancellableKey) as? Cancellable }
      set { objc_setAssociatedObject(self, &subjectCancellableKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
