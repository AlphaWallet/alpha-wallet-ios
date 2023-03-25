// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
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

    init(viewController: UIViewController,
         analytics: AnalyticsLogger,
         sessionsProvider: SessionsProvider) {

        self.viewController = viewController
        self.sessionsProvider = sessionsProvider
        self.analytics = analytics
    }

    func start() {
        UIAlertController.alert(
            title: "\(R.string.localizable.settingsPingInfuraTitle())?",
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
            })
    }

    private func pingInfura() {
        viewController.displayLoading()

        let session = sessionsProvider.activeSessions.anyValue
        session.blockchainProvider.blockNumber()
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    UIAlertController.alert(
                        title: R.string.localizable.settingsPingInfuraFail(),
                        message: "\(error.localizedDescription)",
                        alertButtonTitles: [R.string.localizable.oK()],
                        alertButtonStyles: [.cancel],
                        viewController: self.viewController,
                        style: .alert)
                }
                self.viewController.hideLoading()
                self.delegate?.didPing(in: self)
            }, receiveValue: { _ in
                UIAlertController.alert(
                    title: R.string.localizable.settingsPingInfuraSuccessful(),
                    message: nil,
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
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
