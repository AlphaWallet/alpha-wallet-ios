// Copyright © 2023 Stormbird PTE. LTD.

public func isRunningTests() -> Bool {
    return ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
}

