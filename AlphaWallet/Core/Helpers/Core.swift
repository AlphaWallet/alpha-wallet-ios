// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

func assertImpossibleCodePath(message: String) {
    assert(false, message)
}

func assertImpossibleCodePath() {
    assert(false)
}

func isRunningTests() -> Bool {
    return ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
}

func isAlphaWallet() -> Bool {
    Bundle.main.bundleIdentifier == "com.stormbird.alphawallet"
}

func isRunningOnMac() -> Bool {
    if ProcessInfo.processInfo.isMacCatalystApp {
        return true
    }
    if #available(iOS 14.0, *) {
        return ProcessInfo.processInfo.isiOSAppOnMac
    } else {
        return false
    }
}