// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletFoundation

class LockViewModel {
    let lock: Lock
    
    init(lock: Lock) {
        self.lock = lock
    }
    
    var charCount: Int {
        //This step is required for old clients to support 4 digit passcode.
        var count = 0
        if lock.isPasscodeSet {
            count = lock.currentPasscode!.count
        } else {
            count = 6
        }
        return count
    }
    var isIncorrectMaxAttemptTimeSet: Bool {
        lock.isIncorrectMaxAttemptTimeSet
    }
    var passcodeAttemptLimit: Int {
        //If max attempt limit is reached we should give only 1 attempt.
        return lock.isIncorrectMaxAttemptTimeSet ? 1 : 5
    }
}
