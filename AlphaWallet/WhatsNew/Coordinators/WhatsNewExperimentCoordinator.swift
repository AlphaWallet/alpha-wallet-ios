// Copyright © 2021 Stormbird PTE. LTD.

import AlphaWalletFoundation
import UIKit

protocol WhatsNewExperimentCoordinatorDelegate: AnyObject {
    func didEnd(in coordinator: WhatsNewExperimentCoordinator)
}

class WhatsNewExperimentCoordinator: Coordinator {
    private static let key = "experiments.whatsnew.1"
    private static let walletLastCreatedWindowSkipWhatsNew = TimeInterval(3)

    static var lastCreatedWalletTimestamp: Date?

    private let navigationController: UINavigationController
    private let viewModel = HelpUsViewModel()
    private let analytics: AnalyticsLogger
    private let userDefaults: UserDefaults

    var coordinators: [Coordinator] = []
    weak var delegate: WhatsNewExperimentCoordinatorDelegate?

    //TODO probably need to generalize this. Maybe use AppTracker or a similar, new type
    var hasRan: Bool {
        get {
            userDefaults.bool(forKey: Self.key)
        }
        set {
            userDefaults.set(newValue, forKey: Self.key)
        }
    }

    init(navigationController: UINavigationController, userDefaults: UserDefaults, analytics: AnalyticsLogger) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.userDefaults = userDefaults
        self.analytics = analytics
    }

    func start() {
        //We don't want to show the user What's New right after a wallet is created (not imported) because this will crash with the UI which we used to prompt users to back up the new wallet
        if let lastCreatedWalletTimestamp = Self.lastCreatedWalletTimestamp, Date().timeIntervalSince(lastCreatedWalletTimestamp) < Self.walletLastCreatedWindowSkipWhatsNew {
            return
        }
        guard !hasRan else {
            delegate?.didEnd(in: self)
            return
        }
        hasRan = true

        let coordinator = WhatsNewListingCoordinator(navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        let listings = WhatsNewListing(listing: [
            WhatsNew(
                //TODO localize later. Might not keep this longer term
                title: "",
                changes: [
                    "* Dark Mode",
                    "* Mainnet and testnets can now be enabled at the same time",
                ]),
        ])
        coordinator.start(viewModel: .init(model: listings, title: R.string.localizable.whatsNew(), shouldShowCheckmarks: false))
    }
}

extension WhatsNewExperimentCoordinator: WhatsNewListingCoordinatorDelegate {
    func didDismiss(in coordinator: WhatsNewListingCoordinator) {
        delegate?.didEnd(in: self)
    }
}
