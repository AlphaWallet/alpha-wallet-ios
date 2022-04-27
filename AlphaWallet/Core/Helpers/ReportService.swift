//
//  ReportService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2021.
//

import UIKit

protocol ReportService {
    func configure()
}

class ReportProvider: NSObject {
    private var services: [ReportService] = []

    override init() {
        super.init()

        guard !isRunningTests() else { return }
        guard isAlphaWallet() else { return }
        if let service = AlphaWallet.FirebaseReportService() {
            register(service)
        }
    }

    func register(_ service: ReportService) {
        services.append(service)
    }

    func start() {
        services.forEach { service in
            service.configure()
        }
    }

}
