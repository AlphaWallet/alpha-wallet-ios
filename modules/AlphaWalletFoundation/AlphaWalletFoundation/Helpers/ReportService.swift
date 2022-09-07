//
//  ReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Foundation

public protocol ReportService {
    func configure()
}

public final class ReportProvider: NSObject {
    private var services: [ReportService] = []

    public func register(_ service: ReportService) {
        services.append(service)
    }

    public func start() {
        services.forEach { service in
            service.configure()
        }
    }
}

public enum ReportKey: String {
    case walletAddresses
    case activeWalletAddress
    case activeServers
}

public protocol CrashlyticsReporter {
    func track(wallets: [Wallet])
    func trackActiveWallet(wallet: Wallet)
    func track(enabledServers: [RPCServer])
    @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) -> Bool
}

public fileprivate (set) var crashlytics: CrashlyticsReporter!

public func register(crashlytics object: CrashlyticsReporter) {
    crashlytics = object
}
