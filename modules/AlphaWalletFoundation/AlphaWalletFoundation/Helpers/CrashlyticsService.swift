//
//  CrashlyticsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Foundation
import AlphaWalletCore

public protocol CrashlyticsReporter: AnyObject {
    func track(wallets: [Wallet])
    func trackActiveWallet(wallet: Wallet)
    func track(enabledServers: [RPCServer])
    @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) -> Bool
}

public let crashlytics = CrashlyticsService()

public final class CrashlyticsService: NSObject, CrashlyticsReporter {
    private var services: AtomicArray<CrashlyticsReporter> = .init()

    public override init() { }

    public func register(_ service: CrashlyticsReporter) {
        services.append(service)
    }

    public func track(wallets: [Wallet]) {
        services.forEach { $0.track(wallets: wallets) }
    }

    public func trackActiveWallet(wallet: Wallet) {
        services.forEach { $0.trackActiveWallet(wallet: wallet) }
    }

    public func track(enabledServers: [RPCServer]) {
        services.forEach { $0.track(enabledServers: enabledServers) }
    }

    public func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) -> Bool {
        return services.contains(where: { $0.logLargeNftJsonFiles(for: actions, fileSizeThreshold: fileSizeThreshold) })
    }
}

