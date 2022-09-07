// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

public func assertImpossibleCodePath(message: String) {
    assert(false, message)
}

public func assertImpossibleCodePath() {
    assert(false)
}

public func isRunningTests() -> Bool {
    return ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
}

public func isAlphaWallet() -> Bool {
    Bundle.main.bundleIdentifier == "com.stormbird.alphawallet"
}

public func isRunningOnMac() -> Bool {
    if ProcessInfo.processInfo.isMacCatalystApp {
        return true
    }
    if #available(iOS 14.0, *) {
        return ProcessInfo.processInfo.isiOSAppOnMac
    } else {
        return false
    }
}
