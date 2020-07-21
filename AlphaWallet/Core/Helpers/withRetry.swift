// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

func withRetry(times: Int, task: @escaping (_ triggerRetry: @escaping () -> Bool) -> Void) {
    var retriedCount = 0
    func triggerRetry() -> Bool {
        guard retriedCount < times else { return false }
        retriedCount += 1
        task(triggerRetry)
        return true
    }
    task(triggerRetry)
}
