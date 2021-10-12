//
//  AddRPCServerCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import UIKit
import PromiseKit

protocol AddRPCServerCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: AddRPCServerCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: AddRPCServerCoordinator)
}

class AddRPCServerCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let config: Config
    private let restartQueue: RestartTaskQueue
    private let analyticsCoordinator: AnalyticsCoordinator
    weak var delegate: AddRPCServerCoordinatorDelegate?

    init(navigationController: UINavigationController, config: Config, restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.config = config
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
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
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool> {
        UIAlertController.promptToUseUnresolvedExplorerURL(customChain: customChain, chainId: chainId, viewController: navigationController)
    }

    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        analyticsCoordinator.log(action: Analytics.Action.addCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "user"])
        delegate?.restartToAddEnableAndSwitchBrowserToServer(in: self)
        //Note necessary to pop the navigation controller since we are restarting the UI
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        let alertController = UIAlertController.alertController(title: R.string.localizable.error(), message: error.message, style: .alert, in: navigationController)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }
}

extension UIAlertController {
    static func promptToUseUnresolvedExplorerURL(customChain: WalletAddEthereumChainObject, chainId: Int, viewController: UIViewController) -> Promise<Bool> {
        let (promise, seal) = Promise<Bool>.pending()
        let message = R.string.localizable.addCustomChainWarningNoBlockchainExplorerUrl()
        let alertController = UIAlertController.alertController(title: R.string.localizable.warning(), message: message, style: .alert, in: viewController)
        let continueAction = UIAlertAction(title: R.string.localizable.continue(), style: .destructive, handler: { _ in
            seal.fulfill(true)
        })

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { _ in
            seal.fulfill(false)
        })

        alertController.addAction(continueAction)
        alertController.addAction(cancelAction)

        viewController.present(alertController, animated: true)

        return promise
    }

}
