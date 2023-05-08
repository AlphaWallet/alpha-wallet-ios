// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation

class FakeJailbreakChecker: JailbreakChecker {
    let jailbroken: Bool

    var isJailbroken: Bool {
        return jailbroken
    }

    init(jailbroken: Bool) {
        self.jailbroken = jailbroken
    }
}
