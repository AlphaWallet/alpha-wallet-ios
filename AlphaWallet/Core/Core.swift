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
