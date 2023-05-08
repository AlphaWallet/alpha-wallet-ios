//
//  ConfigureApp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import AlphaWalletENS
import AlphaWalletLogger
import AlphaWalletOpenSea
import Foundation

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