//
//  EditCustomRpcCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit
import PromiseKit

protocol EditCustomRpcCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: EditCustomRpcCoordinator)
    func restartToEdit(in coordinator: EditCustomRpcCoordinator)
}

class EditCustomRpcCoordinator: NSObject, Coordinator {
    private let navigationController: UINavigationController
    private let config: Config
    private let restartQueue: RestartTaskQueue
    private let analyticsCoordinator: AnalyticsCoordinator
    var coordinators: [Coordinator] = []
    weak var delegate: EditCustomRpcCoordinatorDelegate?
    var selectedCustomRpc: CustomRPC

    init(navigationController: UINavigationController, config: Config, restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator, customRpc: CustomRPC) {
        self.navigationController = navigationController
        self.config = config
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
        self.selectedCustomRpc = customRpc
    }

    func start() {
        let viewModel = EditCustomRpcViewModel(model: selectedCustomRpc)
        let viewController = EditCustomRpcViewController(viewModel: viewModel)
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension EditCustomRpcCoordinator: EditCustomRpcViewControllerDelegate {

    func didFinish(in viewController: EditCustomRpcViewController, customRpc: CustomRPC) {
        let explorerEndpoints: [String]?
        let defaultDecimals = 18

        if let endpoint = customRpc.explorerEndpoint {
            explorerEndpoints = [endpoint]
        } else {
            explorerEndpoints = nil
        }

        let customChain = WalletAddEthereumChainObject(nativeCurrency: .init(name: customRpc.nativeCryptoTokenName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customRpc.symbol ?? "", decimals: defaultDecimals), blockExplorerUrls: explorerEndpoints, chainName: customRpc.chainName, chainId: String(customRpc.chainID), rpcUrls: [customRpc.rpcEndpoint])
        let editCustomChain = AddCustomChain(customChain, isTestnet: customRpc.isTestnet, restartQueue: restartQueue, url: nil, operation: .edit(original: customRpc))
        editCustomChain.delegate = self
//        editCustomChain.originalCustomRpc = customRpc
        editCustomChain.run()
    }
}

extension EditCustomRpcCoordinator: AddCustomChainDelegate {
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
