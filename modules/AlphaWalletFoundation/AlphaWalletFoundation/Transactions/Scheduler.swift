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
    var operation: AnyPublisher<Void, PromiseError> { get }
    var interval: TimeInterval { get }
}

protocol SchedulerProtocol {
    func start()
    func resume()
    func cancel()
}

final class Scheduler: SchedulerProtocol {
    private lazy var timer = CombineTimer(interval: provider.interval)
    private let countdownTimer = CombineTimer(interval: 1)
    private let reachability: ReachabilityManagerProtocol
    private let provider: SchedulerProvider
    private lazy var queue = RunLoop.main
    private var cancelable = Set<AnyCancellable>()
    private var schedulerCancelable: AnyCancellable?
    private var isRunning: Bool = false
    private var scheduledTaskCancelable: AnyCancellable?

    @Published var state: Scheduler.State = .idle

    init(provider: SchedulerProvider,
         reachability: ReachabilityManagerProtocol = ReachabilityManager(),
         useCountdownTimer: Bool = false) {

        self.reachability = reachability
        self.provider = provider

        if useCountdownTimer {
            countdownTimer.publisher
                .compactMap { _ -> Scheduler.State? in
                    guard case .tick(let value) = self.state, value - 1 >= 0 else { return nil }
                    return Scheduler.State.tick(value - 1)
                }.assign(to: \.state, on: self)
                .store(in: &cancelable)
        }
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
    
    private func resetCountdownCounter() {
        self.state = .tick(Int(provider.interval))
        countdownTimer.interval = 1
    }

    func resume() {
        guard reachability.isReachable else { return }

        cancel()
        schedulerCancelable = runNewSchedulerCycle()
    }

    func cancel() {
        cancelScheduledTask()
        cancelScheduler()
        state = .idle
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
        state = .loading
        scheduledTaskCancelable = provider.operation
            .receive(on: queue)
            .sink(receiveCompletion: { [weak self] result in
                self?.isRunning = false
                switch result {
                case .failure(let error):
                    self?.state = .done(.failure(error))
                case .finished:
                    self?.state = .done(.success(()))
                }

                self?.resetCountdownCounter()
                self?.schedulerCancelable = self?.runNewSchedulerCycle()
            }, receiveValue: {})
    }

    private func runSchedulerCycleWithInitialCall() -> AnyCancellable {
        return timer.publisher
            .prepend(())
            .sink { [weak self] _ in self?.onTimedCall() }
    }

    private func runNewSchedulerCycle() -> AnyCancellable {
        return timer.publisher
            .sink { [weak self] _ in self?.onTimedCall() }
    }
}

extension Scheduler {
    enum State {
        case idle
        case tick(Int)
        case loading
        case done(Result<Void, Error>)
    }
}
