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
    func restartToEdit(in coordinator: EditCustomRPCCoordinator)
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
        let viewModel = EditCustomRPCViewModel(model: selectedCustomRPC)
        let viewController = EditCustomRPCViewController(viewModel: viewModel)
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension EditCustomRPCCoordinator: EditCustomRPCViewControllerDelegate {

    func didFinish(in viewController: EditCustomRPCViewController, customRPC: CustomRPC) {
        let explorerEndpoints: [String]?
        let defaultDecimals = 18

        if let endpoint = customRPC.explorerEndpoint {
            explorerEndpoints = [endpoint]
        } else {
            explorerEndpoints = nil
        }
        
        let customChain = WalletAddEthereumChainObject(nativeCurrency: .init(name: customRPC.nativeCryptoTokenName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customRPC.symbol ?? "", decimals: defaultDecimals), blockExplorerUrls: explorerEndpoints, chainName: customRPC.chainName, chainId: String(customRPC.chainID), rpcUrls: [customRPC.rpcEndpoint])
        let editCustomChain = EditCustomChain(customChain, isTestnet: customRPC.isTestnet, restartQueue: restartQueue, url: nil)
        editCustomChain.delegate = self
        editCustomChain.originalCustomRPC = customRPC
        editCustomChain.run()
    }
}

extension EditCustomRPCCoordinator: AddCustomChainDelegate {
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool> {
        UIAlertController.promptToUseUnresolvedExplorerURL(customChain: customChain, chainId: chainId, viewController: navigationController)
    }
    
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        delegate?.restartToEdit(in: self)
    }
    
    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        let alertController = UIAlertController.alertController(title: R.string.localizable.error(), message: error.message, style: .alert, in: navigationController)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }
}
