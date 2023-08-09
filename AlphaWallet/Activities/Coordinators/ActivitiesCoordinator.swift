// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol ActivitiesCoordinatorDelegate: AnyObject {
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
}

class ActivitiesCoordinator: NSObject, Coordinator {
    private let sessionsProvider: SessionsProvider
    private let activitiesService: ActivitiesServiceType
    private let keystore: Keystore
    private let wallet: Wallet
    private let analytics: AnalyticsLogger
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenImageFetcher: TokenImageFetcher
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: ActivitiesCoordinatorDelegate?
    lazy var rootViewController: ActivitiesViewController = {
        makeActivitiesViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(analytics: AnalyticsLogger,
         sessionsProvider: SessionsProvider,
         navigationController: UINavigationController = .withOverridenBarAppearence(),
         activitiesService: ActivitiesServiceType,
         keystore: Keystore,
         wallet: Wallet,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.activitiesService = activitiesService
        self.sessionsProvider = sessionsProvider
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
        let controller = ActivitiesViewController(analytics: analytics, keystore: keystore, wallet: wallet, viewModel: viewModel, sessionsProvider: sessionsProvider, assetDefinitionStore: assetDefinitionStore, tokenImageFetcher: tokenImageFetcher)
        controller.delegate = self

        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
    }
}

extension ActivitiesCoordinator: ActivitiesViewControllerDelegate {

    func subscribeForActivitiesUpdates() {
        if Config().development.shouldDisableActivities {
            return
        }
        activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak rootViewController] activities in
                rootViewController?.configure(viewModel: .init(collection: .init(activities: activities)))
            }.store(in: &cancelable)
    }

    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        delegate?.didPressActivity(activity: activity, in: viewController)
    }

    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController) {
        delegate?.didPressTransaction(transaction: transaction, in: viewController)
    }
}
