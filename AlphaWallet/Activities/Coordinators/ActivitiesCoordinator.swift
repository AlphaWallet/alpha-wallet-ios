// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: AnyObject {
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
}

class ActivitiesCoordinator: NSObject, Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let activitiesService: ActivitiesServiceType
    weak var delegate: ActivitiesCoordinatorDelegate?

    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    private var subscriptionKey: Subscribable<ActivitiesViewModel>.SubscribableKey!

    init(
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = .withOverridenBarAppearence(),
        activitiesService: ActivitiesServiceType
    ) {
        self.activitiesService = activitiesService
        self.sessions = sessions
        self.navigationController = navigationController
        super.init()

        subscriptionKey = activitiesService.subscribableViewModel.subscribe { [weak self] viewModel in
            guard let strongSelf = self, let viewModel = viewModel else { return }

            strongSelf.rootViewController.configure(viewModel: viewModel)
        }
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func makeActivitiesViewController() -> ActivitiesViewController {
        let viewModel = ActivitiesViewModel()
        let controller = ActivitiesViewController(viewModel: viewModel, sessions: sessions)
        controller.delegate = self

        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
    }

    func stop() {
        activitiesService.stop()
    }
}

extension ActivitiesCoordinator: ActivitiesViewControllerDelegate {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        delegate?.didPressActivity(activity: activity, in: viewController)
    }

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}
