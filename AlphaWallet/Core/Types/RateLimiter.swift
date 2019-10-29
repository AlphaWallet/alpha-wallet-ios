//Copyright © 2019 Stormbird PTE. LTD.

import Foundation

///One limitation of this class due to simplification: if "requests" keep coming in, each with the time limit from the last, the block will not fire until one of the request gets a breather of `limit`
class RateLimiter {
    private let block: () -> Void
    private let limit: TimeInterval
    private var timer: Timer?

    init(limit: TimeInterval, block: @escaping () -> Void) {
        self.limit = limit
        self.block = block
    }

    func run() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: limit, target: self, selector: #selector(runBlock), userInfo: nil, repeats: false)
    }

    @objc private func runBlock() {
        block()
    }
}
