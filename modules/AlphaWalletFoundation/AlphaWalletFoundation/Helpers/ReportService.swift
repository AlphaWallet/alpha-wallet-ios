//
//  ReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Foundation

public protocol CrashlyticsReporter {
    func track(wallets: [Wallet])
    func trackActiveWallet(wallet: Wallet)
    func track(enabledServers: [RPCServer])
    @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) -> Bool
}

public fileprivate (set) var crashlytics: CrashlyticsReporter = NoOpCrashlyticsReporter()

public func register(crashlytics object: CrashlyticsReporter) {
    crashlytics = object
}

private final class NoOpCrashlyticsReporter: CrashlyticsReporter {
    func track(wallets: [Wallet]) {

    }

    func trackActiveWallet(wallet: Wallet) {

    }

    func track(enabledServers: [RPCServer]) {

    }

    @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) -> Bool {
        return false
    }
}
