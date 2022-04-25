// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivitiesCoordinatorDelegate: AnyObject {
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
}

class ActivitiesCoordinator: NSObject, Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let activitiesService: ActivitiesServiceType
    private var subscriptionKey: Subscribable<ActivitiesViewModel>.SubscribableKey?
    private let keystore: Keystore
    private let wallet: Wallet
    private let analyticsCoordinator: AnalyticsCoordinator
    weak var delegate: ActivitiesCoordinatorDelegate?

    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        analyticsCoordinator: AnalyticsCoordinator,
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = .withOverridenBarAppearence(),
        activitiesService: ActivitiesServiceType,
        keystore: Keystore,
        wallet: Wallet
    ) {
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.sessions = sessions
        self.navigationController = navigationController
        self.keystore = keystore
        self.wallet = wallet
        super.init()
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
        subscribeForActivitiesUpdates()
    }

    private func makeActivitiesViewController() -> ActivitiesViewController {
        let viewModel = ActivitiesViewModel()
        let controller = ActivitiesViewController(analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: wallet, viewModel: viewModel, sessions: sessions)
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

    func subscribeForActivitiesUpdates() {
        subscriptionKey.flatMap { activitiesService.subscribableViewModel.unsubscribe($0) }

        subscriptionKey = activitiesService.subscribableViewModel.subscribe { [weak rootViewController] viewModel in
            guard let viewController = rootViewController, let viewModel = viewModel else { return }

            viewController.configure(viewModel: viewModel)
        }
    }

    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        delegate?.didPressActivity(activity: activity, in: viewController)
    }

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}
