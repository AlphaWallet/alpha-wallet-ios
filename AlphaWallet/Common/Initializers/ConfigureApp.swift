// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletOpenSea

public class ConfigureApp: Initializer {
    public init() {}
    public func perform() {
        ENS.isLoggingEnabled = true
        AlphaWalletOpenSea.OpenSea.isLoggingEnabled = true
    }
}

public class DatabasePathLog: Initializer {
    public init() {}
    public func perform() {
        let config = RealmConfiguration.configuration(name: "")
        debugLog("Database filepath: \(config.fileURL!)")
        debugLog("Database directory: \(config.fileURL!.deletingLastPathComponent())")
    }
}
