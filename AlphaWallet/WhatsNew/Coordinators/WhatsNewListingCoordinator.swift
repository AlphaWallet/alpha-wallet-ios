//
//  WhatsNewListingCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import UIKit
import AlphaWalletFoundation

protocol WhatsNewListingCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: WhatsNewListingCoordinator)
}

class WhatsNewListingCoordinator: NSObject, Coordinator {
    private let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: WhatsNewListingCoordinatorDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }

    func start(viewModel: WhatsNewListingViewModel) {
        let rootViewController = WhatsNewListingViewController(viewModel: viewModel)

        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.set(contentViewController: rootViewController)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        
        navigationController.present(panel, animated: true)
    }
}

extension WhatsNewListingCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.didDismiss(in: self)
    }
}
