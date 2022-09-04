// Copyright SIX DAY LLC. All rights reserved.

import UIKit
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeLock: Lock {
    var passcodeSet = true

    var isPasscodeSet: Bool { return passcodeSet }
    var currentPasscode: String? { return "passcode" }
    var numberOfAttempts: Int { return 0 }
    var recordedMaxAttemptTime: Date { return Date() }
    var isIncorrectMaxAttemptTimeSet: Bool { return false }

    func isPasscodeValid(passcode: String) -> Bool {
        return false
    }

    func setPasscode(passcode: String) {

    }

    func deletePasscode() {

    }

    func resetPasscodeAttemptHistory() {

    }

    func recordIncorrectPasscodeAttempt() {

    }

    func recordIncorrectMaxAttemptTime() {

    }

    func removeIncorrectMaxAttemptTime() {

    }

    func clear() {

    }
}
