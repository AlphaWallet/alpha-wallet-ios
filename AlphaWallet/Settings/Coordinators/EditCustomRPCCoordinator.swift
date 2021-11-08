//
//  EditCustomRPCCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit
import PromiseKit

protocol EditCustomRPCSCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: EditCustomRPCCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: EditCustomRPCCoordinator)
}

class EditCustomRPCCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    private let navigationController: UINavigationController
    private let config: Config
    private let restartQueue: RestartTaskQueue
    private let analyticsCoordinator: AnalyticsCoordinator
    weak var delegate: EditCustomRPCSCoordinatorDelegate?
    var selectedCustomRPC: CustomRPC
    
    init(navigationController: UINavigationController, config: Config, restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator, customRPC: CustomRPC) {
        self.navigationController = navigationController
        self.config = config
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
        self.selectedCustomRPC = customRPC
    }
    func start() {
        let viewModel = EditCustomRPCViewModel(customRPC: selectedCustomRPC)
        let viewController = EditCustomRPCViewController(viewModel: viewModel)
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension EditCustomRPCCoordinator: EditCustomRPCViewControllerDelegate {
    // TODO: Validate the CustomRPC
    func didFinish(in viewController: EditCustomRPCViewController, customRPC: CustomRPC) {
    }
}
