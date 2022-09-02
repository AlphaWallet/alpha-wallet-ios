//
//  Scheduler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import Combine
import AlphaWalletCore

protocol SchedulerProvider: AnyObject {
    var name: String { get }
    var operation: AnyPublisher<Void, SchedulerError> { get }
    var interval: TimeInterval { get }
}

enum SchedulerError: Error {
    case general
    case covalentError(Covalent.CovalentError)
    case promiseError(PromiseError)
}

protocol SchedulerProtocol {
    func start()
    func resume()
    func cancel()
}

final class Scheduler: SchedulerProtocol {
    private lazy var timer = CombineTimer(interval: provider.interval)
    private let reachability: ReachabilityManagerProtocol
    private let provider: SchedulerProvider
    private lazy var queue = DispatchQueue(label: "com.\(provider.name).scheduler.updateQueue")
    private var cancelable = Set<AnyCancellable>()
    private var schedulerCancelable: AnyCancellable?
    private var isRunning: Bool = false
    private var scheduledTaskCancelable: AnyCancellable?

    init(provider: SchedulerProvider, reachability: ReachabilityManagerProtocol = ReachabilityManager()) {
        self.reachability = reachability
        self.provider = provider
    }

    func start() {
        reachability.isReachablePublisher
            .subscribe(on: queue)
            .sink { [weak self] isReachable in
                self?.cancel()

                guard isReachable else { return }
                self?.schedulerCancelable = self?.runSchedulerCycleWithInitialCall()
            }.store(in: &cancelable)
    }

    func resume() {
        guard reachability.isReachable else { return }

        cancel()
        schedulerCancelable = runNewSchedulerCycle()
    }

    func cancel() {
        cancelScheduledTask()
        cancelScheduler()
    }

    private func cancelScheduler() {
        schedulerCancelable?.cancel()
    }

    private func cancelScheduledTask() {
        scheduledTaskCancelable?.cancel()
    }

    private func onTimedCall() {
        guard !isRunning else { return }

        isRunning = true

        cancelScheduledTask()
        scheduledTaskCancelable = provider.operation
            .sink(receiveCompletion: { [weak self] _ in
                self?.isRunning = false
                self?.schedulerCancelable = self?.runNewSchedulerCycle()
            }, receiveValue: {})
    }

    private func runSchedulerCycleWithInitialCall() -> AnyCancellable {
        return timer.publisher
            .prepend(())
            .receive(on: queue)
            .sink { [weak self] _ in self?.onTimedCall() }
    }

    private func runNewSchedulerCycle() -> AnyCancellable {
        return timer.publisher
            .receive(on: queue)
            .sink { [weak self] _ in self?.onTimedCall() }
    }
}
