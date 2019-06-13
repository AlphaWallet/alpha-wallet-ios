// Copyright SIX DAY LLC. All rights reserved.

import UIKit
@testable import AlphaWallet

class FakeLockProtocol: LockInterface {
    var passcodeSet = true

    var isPasscodeSet: Bool {
        return passcodeSet
    }
}
