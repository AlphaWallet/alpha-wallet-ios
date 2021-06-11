//
//  AddRPCServerCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import UIKit

protocol AddRPCServerCoordinatorDelegate: class {
    func didDismiss(in coordinator: AddRPCServerCoordinator)
    func restartToAddEnableAAndSwitchBrowserToServer(in coordinator: AddRPCServerCoordinator)
}

class AddRPCServerCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let config: Config
    private let restartQueue: RestartTaskQueue
    weak var delegate: AddRPCServerCoordinatorDelegate?

    init(navigationController: UINavigationController, config: Config, restartQueue: RestartTaskQueue) {
        self.navigationController = navigationController
        self.config = config
        self.restartQueue = restartQueue
    }

    func start() {
        let viewModel = AddrpcServerViewModel()
        let viewController = AddRPCServerViewController(viewModel: viewModel, config: config)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(backSelected))

        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func backSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)

        delegate?.didDismiss(in: self)
    }

    private func addChain(_ customRpc: CustomRPC) {
        let explorerEndpoints: [String]?
        if let endpoint = customRpc.explorerEndpoint {
            explorerEndpoints = [endpoint]
        } else {
            explorerEndpoints = nil
        }
        let defaultDecimals = 18
        let customChain = WalletAddEthereumChainObject(nativeCurrency: .init(name: customRpc.nativeCryptoTokenName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customRpc.symbol ?? "", decimals: defaultDecimals), blockExplorerUrls: explorerEndpoints, chainName: customRpc.chainName, chainId: String(customRpc.chainID), rpcUrls: [customRpc.rpcEndpoint])
        let addCustomChain = AddCustomChain(customChain, isTestnet: customRpc.isTestnet, restartQueue: restartQueue, url: nil)
        addCustomChain.delegate = self
        addCustomChain.run()
    }
}

extension AddRPCServerCoordinator: AddRPCServerViewControllerDelegate {
    func didFinish(in viewController: AddRPCServerViewController, rpc: CustomRPC) {
        addChain(rpc)
    }
}

extension AddRPCServerCoordinator: AddCustomChainDelegate {
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        delegate?.restartToAddEnableAAndSwitchBrowserToServer(in: self)
        //Note necessary to pop the navigation controller since we are restarting the UI
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        let alertController = UIAlertController.alertController(title: R.string.localizable.error(), message: error.message, style: .alert, in: navigationController)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }
}