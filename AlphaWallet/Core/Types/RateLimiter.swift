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
            shouldRunWhenWindowCloses = true
        } else {
            runWithNewWindow()
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
        timer = Timer.scheduledTimer(timeInterval: limit, target: self, selector: #selector(windowIsClosed), userInfo: nil, repeats: false)
    }
}
