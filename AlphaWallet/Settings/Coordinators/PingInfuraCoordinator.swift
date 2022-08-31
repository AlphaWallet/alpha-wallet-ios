// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol PingInfuraCoordinatorDelegate: AnyObject {
    func didPing(in coordinator: PingInfuraCoordinator)
    func didCancel(in coordinator: PingInfuraCoordinator)
}

class PingInfuraCoordinator: Coordinator {
    private let viewController: UIViewController
    private let analytics: AnalyticsLogger
    private lazy var provider = GetBlockNumber(server: .main, analytics: analytics)

    var coordinators: [Coordinator] = []
    weak var delegate: PingInfuraCoordinatorDelegate?

    init(inViewController viewController: UIViewController, analytics: AnalyticsLogger) {
        self.viewController = viewController
        self.analytics = analytics
    }

    func start() {
        UIAlertController.alert(title: "\(R.string.localizable.settingsPingInfuraTitle())?",
                message: nil,
                alertButtonTitles: [R.string.localizable.oK(), R.string.localizable.cancel()],
                alertButtonStyles: [.default, .cancel],
                viewController: viewController,
                completion: { choice in
                    guard choice == 0 else {
                        self.delegate?.didCancel(in: self)
                        return
                    }
                    self.pingInfura()
                    self.logUse()
                    self.delegate?.didPing(in: self)
                })
    }

    private func pingInfura() {
        firstly {
            provider.getBlockNumber()
        }.done { _ in
            UIAlertController.alert(
                    title: R.string.localizable.settingsPingInfuraSuccessful(),
                    message: nil,
                    alertButtonTitles: [
                        R.string.localizable.oK()
                    ],
                    alertButtonStyles: [
                        .cancel
                    ],
                    viewController: self.viewController,
                    style: .alert)
        }.catch { error in
            UIAlertController.alert(title: R.string.localizable.settingsPingInfuraFail(),
                    message: "\(error.prettyError)",
                    alertButtonTitles: [
                        R.string.localizable.oK(),
                    ],
                    alertButtonStyles: [
                        .cancel
                    ],
                    viewController: self.viewController,
                    style: .alert)
        }
    }
}

// MARK: Analytics
extension PingInfuraCoordinator {
    private func logUse() {
        analytics.log(action: Analytics.Action.pingInfura)
    }
}
