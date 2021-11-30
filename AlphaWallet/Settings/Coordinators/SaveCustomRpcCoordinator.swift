//
//  SaveCustomRpcCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit
import PromiseKit

protocol SaveCustomRpcCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: SaveCustomRpcCoordinator)
    func restartToEdit(in coordinator: SaveCustomRpcCoordinator)
}

enum SaveOperationType {
    case add
    case edit(CustomRPC)

    var customRpc: CustomRPC {
        switch self {
        case .add:
            return CustomRPC.blank
        case .edit(let customRpc):
            return customRpc
        }
    }
}

class SaveCustomRpcCoordinator: NSObject, Coordinator {
    private let navigationController: UINavigationController
    private let config: Config
    private let restartQueue: RestartTaskQueue
    private let analyticsCoordinator: AnalyticsCoordinator
    private let operation: SaveOperationType
    private var viewController: SaveCustomRpcViewController?
    var coordinators: [Coordinator] = []
    weak var delegate: SaveCustomRpcCoordinatorDelegate?

    init(navigationController: UINavigationController, config: Config, restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator, operation: SaveOperationType) {
        self.navigationController = navigationController
        self.config = config
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
        self.operation = operation
    }

    func start() {
        let viewModel = SaveCustomRpcViewModel(model: operation.customRpc)
        let viewController = SaveCustomRpcViewController(viewModel: viewModel)
        self.viewController = viewController
        viewController.delegate = self
        setNaviationTitle(viewController: viewController)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func setNaviationTitle(viewController: SaveCustomRpcViewController) {
        switch operation {
        case .add:
            viewController.navigationItem.title = R.string.localizable.addrpcServerNavigationTitle()
        case .edit:
            viewController.navigationItem.title = R.string.localizable.editCustomRPCNavigationTitle()
        }
    }
}

extension SaveCustomRpcCoordinator: SaveCustomRpcViewControllerDelegate {
    func didFinish(in viewController: SaveCustomRpcViewController, customRpc: CustomRPC) {
        let explorerEndpoints: [String]?
        let defaultDecimals = 18

        if let endpoint = customRpc.explorerEndpoint {
            explorerEndpoints = [endpoint]
        } else {
            explorerEndpoints = nil
        }

        let customChain = WalletAddEthereumChainObject(nativeCurrency: .init(name: customRpc.nativeCryptoTokenName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customRpc.symbol ?? "", decimals: defaultDecimals), blockExplorerUrls: explorerEndpoints, chainName: customRpc.chainName, chainId: String(customRpc.chainID), rpcUrls: [customRpc.rpcEndpoint])
        let saveCustomChain = AddCustomChain(customChain, isTestnet: customRpc.isTestnet, restartQueue: restartQueue, url: nil, operation: operation)
        saveCustomChain.delegate = self
        saveCustomChain.run()
    }
}

extension SaveCustomRpcCoordinator: AddCustomChainDelegate {
    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool> {
        UIAlertController.promptToUseUnresolvedExplorerURL(customChain: customChain, chainId: chainId, viewController: navigationController)
    }

    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        switch operation {
        case .add:
            analyticsCoordinator.log(action: Analytics.Action.addCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "user"])
        case .edit:
            analyticsCoordinator.log(action: Analytics.Action.editCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "user"])
        }
        delegate?.restartToEdit(in: self)
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        let alertController = UIAlertController.alertController(title: R.string.localizable.error(), message: error.message, style: .alert, in: navigationController)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func notifyRpcURlHostnameFailure() {
        DispatchQueue.main.async {
            self.viewController?.handleRpcUrlFailure()
        }
    }
}

fileprivate extension CustomRPC {
    static let blank: CustomRPC = CustomRPC(chainID: 0, nativeCryptoTokenName: nil, chainName: "", symbol: nil, rpcEndpoint: "", explorerEndpoint: nil, etherscanCompatibleType: .unknown, isTestnet: false)
}
