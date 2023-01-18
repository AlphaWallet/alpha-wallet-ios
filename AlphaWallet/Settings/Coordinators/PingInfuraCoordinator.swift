// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation
import Combine

protocol PingInfuraCoordinatorDelegate: AnyObject {
    func didPing(in coordinator: PingInfuraCoordinator)
    func didCancel(in coordinator: PingInfuraCoordinator)
}

class PingInfuraCoordinator: Coordinator {
    private let viewController: UIViewController
    private let analytics: AnalyticsLogger
    private let sessionsProvider: SessionsProvider
    private var cancellable = Set<AnyCancellable>()

    var coordinators: [Coordinator] = []
    weak var delegate: PingInfuraCoordinatorDelegate?

    init(viewController: UIViewController, analytics: AnalyticsLogger, sessionsProvider: SessionsProvider) {
        self.viewController = viewController
        self.sessionsProvider = sessionsProvider
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
        sessionsProvider
            .activeSessions
            .anyValue
            .blockchainProvider
            .blockNumber()
            .sink(receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
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

            }, receiveValue: { _ in
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
            }).store(in: &cancellable)
    }
}

// MARK: Analytics
extension PingInfuraCoordinator {
    private func logUse() {
        analytics.log(action: Analytics.Action.pingInfura)
    }
}
