// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public class DeviceChecker: JailbreakChecker {
    public init() {}
    public var isJailbroken: Bool {
        if TARGET_IPHONE_SIMULATOR == 1 {
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
