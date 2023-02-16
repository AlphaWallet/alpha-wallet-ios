// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletFoundation

class DeviceChecker: JailbreakChecker {
    init() {}

    //A property to workaround this build warning:
    //Will never be executed
    //The warning refers to the lines after the `return` statement following the `targetEnvironment(simulator)` check
    private let isPhoneSimulator: Bool = {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }()

    var isJailbroken: Bool {
        if isPhoneSimulator {
            return false
        }

        if isRunningOnMac() {
            return false
        }

        let list: [String] = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
        ]

        return !list.filter { FileManager.default.fileExists(atPath: $0) }.isEmpty
    }
}
