//Copyright © 2019 Stormbird PTE. LTD.

import Foundation

class RateLimiter {
    private let name: String?
    private let block: () -> Void
    private let limit: TimeInterval
    private var timer: Timer?
    private var shouldRunWhenWindowCloses = false
    private var isWindowActive: Bool {
        timer?.isValid ?? false
    }

    init(name: String? = nil, limit: TimeInterval, autoRun: Bool = false, block: @escaping () -> Void) {
        self.name = name
        self.limit = limit
        self.block = block
        if autoRun {
            run()
        }
    }

    func run() {
        if isWindowActive {
            if Thread.isMainThread {
                shouldRunWhenWindowCloses = true
            } else {
                //TODO replace this class with one (TimedLimiter?) that does this properly
                DispatchQueue.main.async { [weak self] in
                    self?.shouldRunWhenWindowCloses = true
                }
            }
        } else {
            if !Thread.isMainThread {
                runWithNewWindow()
            } else {
                //TODO replace this class with one (TimedLimiter?) that does this properly
                DispatchQueue.main.async { [weak self] in
                    self?.runWithNewWindow()
                }
            }
        }
    }

    @objc private func windowIsClosed() {
        if shouldRunWhenWindowCloses {
            runWithNewWindow()
        }
    }

    private func runWithNewWindow() {
        shouldRunWhenWindowCloses = false
        block()
        timer?.invalidate()
        //NOTE: avoid memory leak, remove capturing self
        timer = Timer.scheduledTimer(withTimeInterval: limit, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.windowIsClosed()
        }
    }
}

public protocol SyncLimiter {
    @discardableResult func execute(_ block: () -> Void) -> Bool
    func reset()
}

extension SyncLimiter {
    public func execute<T>(_ block: () -> T) -> T? {
        var value: T?

        execute {
            value = block()
        }

        return value
    }
}

public final class TimedLimiter: SyncLimiter {

    // MARK: - Properties
    public let limit: TimeInterval
    public private(set) var lastExecutedAt: Date?

    private let syncQueue = DispatchQueue(label: "com.alphaWallet.ratelimit", attributes: [])

    // MARK: - Initializers
    public init(limit: TimeInterval) {
        self.limit = limit
    }

    // MARK: - Limiter
    @discardableResult public func execute(_ block: () -> Void) -> Bool {
        let executed = syncQueue.sync { () -> Bool in
            let now = Date()
            let timeInterval = now.timeIntervalSince(lastExecutedAt ?? .distantPast)

            if timeInterval > limit {
                lastExecutedAt = now

                return true
            } else {
                return false
            }
        }

        if executed {
            block()
        }

        return executed
    }

    public func reset() {
        syncQueue.sync {
            lastExecutedAt = nil
        }
    }
}
