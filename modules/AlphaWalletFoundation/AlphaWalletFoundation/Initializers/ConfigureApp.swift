//
//  ConfigureApp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Foundation
import AlphaWalletOpenSea
import AlphaWalletENS

public class ConfigureApp: Initializer {
    public init() {}
    public func perform() {
        ENS.isLoggingEnabled = true
        AlphaWalletOpenSea.OpenSea.isLoggingEnabled = true
    }
}

import AlphaWalletLogger
public class DatabasePathLog: Initializer {
    public init() {}
    public func perform() {
        let config = RealmConfiguration.configuration(name: "")
        debugLog("Database filepath: \(config.fileURL!)")
        debugLog("Database directory: \(config.fileURL!.deletingLastPathComponent())")
    }
}

public class TickerIdsMatchLog: Initializer {
    public init() {}
    public func perform() {
        if Features.default.isAvailable(.isLoggingEnabledForTickerMatches) {
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                infoLog("Ticker ID positive matching counts: \(TickerIdFilter.matchCounts)")
            }
        }
    }
}

