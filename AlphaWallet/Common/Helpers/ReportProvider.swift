//
//  ReportProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.09.2022.
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
