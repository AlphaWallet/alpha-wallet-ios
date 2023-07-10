// Copyright © 2023 Stormbird PTE. LTD.

extension UserDefaults {
    //NOTE: its quite important to use single instance of user defaults, otherwise the data will be written in different suites
    private static let testSuiteDefaults = UserDefaults(suiteName: NSUUID().uuidString)!

    public static var standardOrForTests: UserDefaults {
        if isRunningTests() {
            return testSuiteDefaults
        } else {
            return .standard
        }
    }
}
