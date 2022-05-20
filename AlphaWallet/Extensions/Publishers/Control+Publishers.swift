//
//  Control+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.03.2022.
//

import UIKit
import Combine

extension UIControl {
    func publisher(forEvent event: Event = .primaryActionTriggered) -> Publishers.Control {
        .init(control: self, event: event)
    }
}

extension Publishers {
    struct Control: Publisher {
        typealias Output = Void
        typealias Failure = Never

        private let control: UIControl
        private let event: UIControl.Event

        init(control: UIControl, event: UIControl.Event) {
            self.control = control
            self.event = event
        }

        func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Void == S.Input {
            subscriber.receive(subscription: Subscription(subscriber, control, event))
        }

        private class Subscription<S>: NSObject, Combine.Subscription where S: Subscriber, S.Input == Void, S.Failure == Never {
            private var subscriber: S?
            private weak var control: UIControl?
            private let event: UIControl.Event
            private var unconsumedDemand = Subscribers.Demand.none
            private var unconsumedEvents = 0

            init(_ subscriber: S, _ control: UIControl, _ event: UIControl.Event) {
                self.subscriber = subscriber
                self.control = control
                self.event = event
                super.init()

                control.addTarget(self, action: #selector(onEvent), for: event)
            }

            deinit {
                control?.removeTarget(self, action: #selector(onEvent), for: event)
            }

            func request(_ demand: Subscribers.Demand) {
                unconsumedDemand += demand
                consumeDemand()
            }

            func cancel() {
                subscriber = nil
            }

            private func consumeDemand() {
                while let subscriber = subscriber, unconsumedDemand > 0, unconsumedEvents > 0 {
                    unconsumedDemand -= 1
                    unconsumedEvents -= 1
                    unconsumedDemand += subscriber.receive(())
                }
            }

            @objc private func onEvent() {
                unconsumedEvents += 1
                consumeDemand()
            }
        }
    }
}

extension Publisher {

    /// Includes the current element as well as the previous element from the upstream publisher in a tuple where the previous element is optional.
    /// The first time the upstream publisher emits an element, the previous element will be `nil`.
    ///
    ///     let range = (1...5)
    ///     cancellable = range.publisher
    ///         .withPrevious()
    ///         .sink { print ("(\($0.previous), \($0.current))", terminator: " ") }
    ///      // Prints: "(nil, 1) (Optional(1), 2) (Optional(2), 3) (Optional(3), 4) (Optional(4), 5) ".
    ///
    /// - Returns: A publisher of a tuple of the previous and current elements from the upstream publisher.
    func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
// swiftlint:disable syntactic_sugar
        scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
// swiftlint:enable syntactic_sugar
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    /// Includes the current element as well as the previous element from the upstream publisher in a tuple where the previous element is not optional.
    /// The first time the upstream publisher emits an element, the previous element will be the `initialPreviousValue`.
    ///
    ///     let range = (1...5)
    ///     cancellable = range.publisher
    ///         .withPrevious(0)
    ///         .sink { print ("(\($0.previous), \($0.current))", terminator: " ") }
    ///      // Prints: "(0, 1) (1, 2) (2, 3) (3, 4) (4, 5) ".
    ///
    /// - Parameter initialPreviousValue: The initial value to use as the "previous" value when the upstream publisher emits for the first time.
    /// - Returns: A publisher of a tuple of the previous and current elements from the upstream publisher.
    func withPrevious(_ initialPreviousValue: Output) -> AnyPublisher<(previous: Output, current: Output), Failure> {
        scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
    }
}
