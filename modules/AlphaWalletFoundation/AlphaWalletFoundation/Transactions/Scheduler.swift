//
//  Scheduler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public enum SchedulerProviderState: Int {
    case initial
    case stopped
    case failured

    public init(int: Int) {
        self = SchedulerProviderState(rawValue: int) ?? .initial
    }
}

public protocol SchedulerStateProvider: AnyObject {
    var state: SchedulerProviderState { get set }
}

protocol SchedulerProvider: AnyObject {
    var name: String { get }
    var operation: AnyPublisher<Void, PromiseError> { get }
    var interval: TimeInterval { get }
}

protocol SchedulerProtocol {
    func start()
    func restart(force: Bool)
    func cancel()
}

extension SchedulerProtocol {
    func restart() {
        restart(force: false)
    }
}

enum SchedulerError: Error {
    case cancelled
}

final class Scheduler: SchedulerProtocol {
    private lazy var timer = CombineTimer(interval: provider.interval)
    private var refreshAggressivelyTimer: CombineTimer?
    private let reachability: ReachabilityManagerProtocol
    private lazy var queue = RunLoop.main
    private var cancelable = Set<AnyCancellable>()
    private var schedulerCancelable: AnyCancellable?
    private var isRunning: Bool = false
    private var scheduledTaskCancelable: AnyCancellable?

    @Published var state: Scheduler.State = .idle
    let provider: SchedulerProvider

    init(provider: SchedulerProvider, reachability: ReachabilityManagerProtocol = ReachabilityManager(), refreshAggressively: Bool = false) {
        self.reachability = reachability
        self.provider = provider

        if refreshAggressively {
            let timer = CombineTimer(interval: 1)
            refreshAggressivelyTimer = timer
            timer.publisher
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
        refreshAggressivelyTimer?.interval = 1
    }

    func restart(force: Bool = false) {
        guard reachability.isReachable else { return }

        cancel()
        schedulerCancelable = force ? runSchedulerCycleWithInitialCall() : runNewSchedulerCycle()
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
                    if case SchedulerError.cancelled = error.embedded {
                        self?.cancel()
                        return
                    }
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

public class PersistantSchedulerStateProvider: SchedulerStateProvider {
    private let defaults: UserDefaults
    private let sessionID: String
    private let prefix: String

    public var state: SchedulerProviderState {
        get { return SchedulerProviderState(int: defaults.integer(forKey: fetchingStateKey)) }
        set { return defaults.set(newValue.rawValue, forKey: fetchingStateKey) }
    }

    private var fetchingStateKey: String {
        return "\(prefix)-\(sessionID)"
    }

    public init(sessionID: String,
                prefix: String,
                defaults: UserDefaults = .standardOrForTests) {

        self.prefix = prefix
        self.sessionID = sessionID
        self.defaults = defaults
    }

    public static func resetFetchingState(account: Wallet,
                                          servers: [RPCServer],
                                          state: SchedulerProviderState = .initial) {

        for server in servers {
            let sessionID = WalletSession.functional.sessionID(account: account, server: server)
            for prefix in EtherscanCompatibleSchedulerStatePrefix.allCases {
                PersistantSchedulerStateProvider(sessionID: sessionID, prefix: prefix.rawValue).state = state
            }

            for prefix in TransactionFetchType.allCases {
                PersistantSchedulerStateProvider(sessionID: sessionID, prefix: prefix.rawValue).state = state
            }
        }
    }
}

enum EtherscanCompatibleSchedulerStatePrefix: String, CaseIterable {
    case normalTransactions = "normalTransactions"
    case oldestTransaction = "transactions.fetchingState" // Migration from TransactionFetchingState, keep as it is
    case erc20LatestTransactions = "erc20LatestTransactions"
    case erc721LatestTransactions = "erc721LatestTransactions"
    case erc1155LatestTransactions = "erc1155LatestTransactions"
}
