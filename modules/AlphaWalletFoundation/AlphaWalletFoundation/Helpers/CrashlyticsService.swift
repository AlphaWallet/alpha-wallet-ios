//
//  CrashlyticsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import Foundation
import AlphaWalletCore

public protocol CrashlyticsReporter: AnyObject {
    func track(wallets: [Wallet]) async
    func trackActiveWallet(wallet: Wallet) async
    func track(enabledServers: [RPCServer]) async
    @discardableResult func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) async -> Bool
}

public let crashlytics = CrashlyticsService()

public final actor CrashlyticsService: NSObject, CrashlyticsReporter {
    private var services: [CrashlyticsReporter] = []

    public override init() { }

    public func register(_ service: CrashlyticsReporter) {
        services.append(service)
    }

    public func track(wallets: [Wallet]) async {
        for each in services {
            await each.track(wallets: wallets)
        }
    }

    public func trackActiveWallet(wallet: Wallet) async {
        for each in services {
            await each.trackActiveWallet(wallet: wallet)
        }
    }

    public func track(enabledServers: [RPCServer]) async {
        for each in services {
            await each.track(enabledServers: enabledServers)
        }
    }

    public func logLargeNftJsonFiles(for actions: [AddOrUpdateTokenAction], fileSizeThreshold: Double) async -> Bool {
        return await services.asyncContains(where: { await $0.logLargeNftJsonFiles(for: actions, fileSizeThreshold: fileSizeThreshold) })
    }
}

