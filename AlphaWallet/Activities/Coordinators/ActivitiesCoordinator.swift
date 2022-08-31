// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol ActivitiesCoordinatorDelegate: AnyObject {
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
}

class ActivitiesCoordinator: NSObject, Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let activitiesService: ActivitiesServiceType
    private let keystore: Keystore
    private let wallet: Wallet
    private let analytics: AnalyticsLogger
    private let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: ActivitiesCoordinatorDelegate?
    private var cancelable = Set<AnyCancellable>()

    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        analytics: AnalyticsLogger,
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = .withOverridenBarAppearence(),
        activitiesService: ActivitiesServiceType,
        keystore: Keystore,
        wallet: Wallet,
        assetDefinitionStore: AssetDefinitionStore
    ) {
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
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
        let viewModel = ActivitiesViewModel(collection: .init())
        let controller = ActivitiesViewController(analytics: analytics, keystore: keystore, wallet: wallet, viewModel: viewModel, sessions: sessions, assetDefinitionStore: assetDefinitionStore)
        controller.delegate = self
        
        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
    }
}

extension ActivitiesCoordinator: ActivitiesViewControllerDelegate {

    func subscribeForActivitiesUpdates() {
        activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak rootViewController] activities in
                rootViewController?.configure(viewModel: .init(collection: .init(activities: activities)))
            }.store(in: &cancelable)
    }

    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        delegate?.didPressActivity(activity: activity, in: viewController)
    }

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}
