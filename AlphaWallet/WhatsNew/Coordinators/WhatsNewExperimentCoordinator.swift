// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol WhatsNewExperimentCoordinatorDelegate: AnyObject {
    func didEnd(in coordinator: WhatsNewExperimentCoordinator)
}

class WhatsNewExperimentCoordinator: Coordinator {
    static private let key = "experiments.whatsnew.1"
    static private let walletLastCreatedWindowSkipWhatsNew = TimeInterval(3)

    static var lastCreatedWalletTimestamp: Date?

    private let navigationController: UINavigationController
    private let viewModel = HelpUsViewModel()
    private let analyticsCoordinator: AnalyticsCoordinator
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

    init(navigationController: UINavigationController, userDefaults: UserDefaults, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.userDefaults = userDefaults
        self.analyticsCoordinator = analyticsCoordinator
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
        addCoordinator(coordinator)
        let listings = WhatsNewListing(listing: [
            WhatsNew(
                    //TODO localize later. Might not keep this longer term
                    title: "You can get to your wallet address QR code from Siri/Spotlight?",
                    changes: [
                        "1. Go to homescreen",
                        "2. Pull down to reveal search bar",
                        "3. Type: wallet QR",
                    ])
        ])
        coordinator.display(viewModel: .init(model: listings, title: R.string.localizable.whatsNew(), shouldShowCheckmarks: false), delegate: self)
    }
}

extension WhatsNewExperimentCoordinator: WhatsNewListingCoordinatorProtocol {
    func didDismiss(controller: WhatsNewListingViewController) {
        delegate?.didEnd(in: self)
    }
}