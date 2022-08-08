//
//  RetryIf.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Foundation
import Combine

fileprivate extension RunLoop.SchedulerTimeType.Stride {
    func nextRandomInterval(upTo value: Int = 5) -> RunLoop.SchedulerTimeType.Stride {
        let jitter = Int.random(in: 0 ..< value)
        return .init(self.timeInterval + Double(jitter))
    }
}

extension Publishers {
    public struct RetryIf<P: Publisher>: Publisher {
        public typealias Output = P.Output
        public typealias Failure = P.Failure

        let publisher: P
        let times: Int
        let condition: (P.Failure) -> Bool

        public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            guard times > 0 else { return publisher.receive(subscriber: subscriber) }

            publisher.catch { (error: P.Failure) -> AnyPublisher<Output, Failure> in
                if condition(error) {
                    return RetryIf(publisher: publisher, times: times - 1, condition: condition).eraseToAnyPublisher()
                } else {
                    return .fail(error)
                }
            }.receive(subscriber: subscriber)
        }
    }

    public struct RetryDelay<P: Publisher, S: Combine.Scheduler>: Publisher {
        public typealias Output = P.Output
        public typealias Failure = P.Failure

        let attempt: UInt
        let upstream: P
        let behavior: RetryBehavior<S>
        let shouldRetry: RetryPredicate?
        let tolerance: S.SchedulerTimeType.Stride?
        let scheduler: S

        public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            guard attempt > 0 else { return upstream.receive(subscriber: subscriber) }

            let conditions = behavior.calculateConditions(attempt)

            upstream.catch { (error: P.Failure) -> AnyPublisher<Output, Failure> in
                guard attempt <= conditions.maxRetries else { return .fail(error) }

                if let shouldRetry = shouldRetry, !shouldRetry(error) { return .fail(error) }

                let upstream = RetryDelay(attempt: attempt + 1, upstream: upstream, behavior: behavior, shouldRetry: shouldRetry, tolerance: tolerance, scheduler: scheduler)

                guard conditions.delay != .zero else { return upstream.eraseToAnyPublisher() }

                return Publishers.Delay(upstream: upstream, interval: conditions.delay, tolerance: tolerance ?? 0, scheduler: scheduler)
                    .eraseToAnyPublisher()
            }.receive(subscriber: subscriber)
        }
    }
}

extension Publisher {

    public func retry<T: Combine.Scheduler>(_ retries: Int, delay: T.SchedulerTimeType.Stride, scheduler: T) -> AnyPublisher<Output, Failure> {
        self.catch { _ -> AnyPublisher<Output, Failure> in
            return Just(())
                .delay(for: delay, scheduler: scheduler)
                .setFailureType(to: Failure.self)
                .flatMap { _ in self }
                .retry(retries > 0 ? retries - 1 : 0)
                .eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    public func retry(times: Int, when condition: @escaping (Failure) -> Bool = { _ in return true }) -> Publishers.RetryIf<Self> {
        Publishers.RetryIf(publisher: self, times: times, condition: condition)
    }

    /**
       Retries the failed upstream publisher using the given retry behavior.
       - parameter behavior: The retry behavior that will be used in case of an error.
       - parameter shouldRetry: An optional custom closure which uses the downstream error to determine
       if the publisher should retry.
       - parameter tolerance: The allowed tolerance in firing delayed events.
       - parameter scheduler: The scheduler that will be used for delaying the retry.
       - parameter options: Options relevant to the scheduler’s behavior.
       - returns: A publisher that attempts to recreate its subscription to a failed upstream publisher.
       */
    public func retry<S: Combine.Scheduler>(_ behavior: RetryBehavior<S>, shouldRetry: RetryPredicate? = nil, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.RetryDelay<Self, S> {
        Publishers.RetryDelay(attempt: 1, upstream: self, behavior: behavior, shouldRetry: shouldRetry, tolerance: tolerance, scheduler: scheduler)
    }

}

/**
 Provides the retry behavior that will be used - the number of retries and the delay between two subsequent retries.
 - `.immediate`: It will immediatelly retry for the specified retry count
 - `.delayed`: It will retry for the specified retry count, adding a fixed delay between each retry
 - `.exponentialDelayed`: It will retry for the specified retry count.
 The delay will be incremented by the provided multiplier after each iteration
 (`multiplier = 0.5` corresponds to 50% increase in time between each retry)
 - `.custom`: It will retry for the specified retry count. The delay will be calculated by the provided custom closure.
 The closure's argument is the current retry
 */
public enum RetryBehavior<S> where S: Combine.Scheduler {
    case immediate(retries: UInt)
    case delayed(retries: UInt, time: TimeInterval)
    case exponentialDelayed(retries: UInt, initial: TimeInterval, multiplier: Double)
    case randomDelayed(retries: UInt, delayBeforeRetry: TimeInterval, delayUpperRangeValueFrom0To: Int)
    case custom(retries: UInt, delayCalculator: (UInt) -> TimeInterval)
}

fileprivate extension RetryBehavior {

    func calculateConditions(_ currentRetry: UInt) -> (maxRetries: UInt, delay: S.SchedulerTimeType.Stride) {
        switch self {
        case let .immediate(retries):
            // If immediate, returns 0.0 for delay
            return (maxRetries: retries, delay: .zero)
        case let .delayed(retries, time):
            // Returns the fixed delay specified by the user
            return (maxRetries: retries, delay: .seconds(time))
        case let .exponentialDelayed(retries, initial, multiplier):
            // If it is the first retry the initial delay is used, otherwise it is calculated
            let delay = currentRetry == 1 ? initial : initial * pow(1 + multiplier, Double(currentRetry - 1))
            return (maxRetries: retries, delay: .seconds(delay))
        case let .custom(retries, delayCalculator):
            // Calculates the delay with the custom calculator
            return (maxRetries: retries, delay: .seconds(delayCalculator(currentRetry)))
        case let .randomDelayed(retries, delayBeforeRetry, delayUpperRangeValueFrom0To):
            let jitter = Int.random(in: 0 ..< Int(delayUpperRangeValueFrom0To))
            let delay = delayBeforeRetry + Double(jitter)

            return (maxRetries: retries, delay: .seconds(delay))
        }
    }

}

public typealias RetryPredicate = (Error) -> Bool
