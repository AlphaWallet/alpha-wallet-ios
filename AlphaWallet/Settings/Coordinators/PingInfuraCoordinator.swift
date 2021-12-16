// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import APIKit
import JSONRPCKit
import PromiseKit

protocol PingInfuraCoordinatorDelegate: AnyObject {
    func didPing(in coordinator: PingInfuraCoordinator)
    func didCancel(in coordinator: PingInfuraCoordinator)
}

class PingInfuraCoordinator: Coordinator {
    private let viewController: UIViewController
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []
    weak var delegate: PingInfuraCoordinatorDelegate?

    init(inViewController viewController: UIViewController, analyticsCoordinator: AnalyticsCoordinator) {
        self.viewController = viewController
        self.analyticsCoordinator = analyticsCoordinator
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
        let request = EtherServiceRequest(server: .main, batch: BatchFactory().create(BlockNumberRequest()))
        firstly {
            Session.send(request)
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
                    message: "\(error)",
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
        analyticsCoordinator.log(action: Analytics.Action.pingInfura)
    }
}