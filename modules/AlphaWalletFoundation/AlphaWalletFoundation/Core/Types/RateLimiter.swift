//Copyright © 2019 Stormbird PTE. LTD.

import Foundation

public class RateLimiter {
    private let name: String?
    private let block: () -> Void
    private let limit: TimeInterval
    private var timer: Timer?
    private var shouldRunWhenWindowCloses = false
    private var isWindowActive: Bool {
        timer?.isValid ?? false
    }

    public init(name: String? = nil, limit: TimeInterval, autoRun: Bool = false, block: @escaping () -> Void) {
        self.name = name
        self.limit = limit
        self.block = block
        if autoRun {
            run()
        }
    }

    public func run() {
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
