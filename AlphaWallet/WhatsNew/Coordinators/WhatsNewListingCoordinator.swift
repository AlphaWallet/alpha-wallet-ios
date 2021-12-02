//
//  WhatsNewListingCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import UIKit

@objc protocol WhatsNewListingCoordinatorProtocol {
    func didDismiss(controller: WhatsNewListingViewController)
}

class WhatsNewListingCoordinator: NSObject, Coordinator {
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }

    func display(viewModel: WhatsNewListingViewModel, delegate: WhatsNewListingCoordinatorProtocol) {
        let viewController = WhatsNewListingViewController(viewModel: viewModel)
        viewController.whatsNewListingDelegate = delegate
        navigationController.present(viewController, animated: true)
    }
}