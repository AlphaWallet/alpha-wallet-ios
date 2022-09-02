// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol DappRequestSwitchCustomChainCoordinatorDelegate: AnyObject {
    func notifySuccessful(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func switchBrowserToExistingServer(_ server: RPCServer, callbackId: SwitchCustomChainCallbackId, url: URL?, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func userCancelled(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func failed(withError error: DAppError, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    //This might not always been called. We call it when there's no other delegate function to call to inform the delegate to remove this coordinator
    func cleanup(coordinator: DappRequestSwitchCustomChainCoordinator)
}

class DappRequestSwitchCustomChainCoordinator: NSObject, Coordinator {
    private var addCustomChain: (chain: AddCustomChain, callbackId: SwitchCustomChainCallbackId)?
    private let config: Config
    let server: RPCServer
    let callbackId: SwitchCustomChainCallbackId
    private let customChain: WalletAddEthereumChainObject
    private let restartQueue: RestartTaskQueue
    private let analytics: AnalyticsLogger
    private let currentUrl: URL?
    private let viewController: UIViewController

    var coordinators: [Coordinator] = []
    weak var delegate: DappRequestSwitchCustomChainCoordinatorDelegate?

    init(config: Config, server: RPCServer, callbackId: SwitchCustomChainCallbackId, customChain: WalletAddEthereumChainObject, restartQueue: RestartTaskQueue, analytics: AnalyticsLogger, currentUrl: URL?, inViewController viewController: UIViewController) {
        self.config = config
        self.server = server
        self.callbackId = callbackId
        self.customChain = customChain
        self.restartQueue = restartQueue
        self.analytics = analytics
        self.currentUrl = currentUrl
        self.viewController = viewController
    }

    func start() {
        guard let customChainId = Int(chainId0xString: customChain.chainId) else {
            delegate?.failed(withErrorMessage: R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId), withCallbackId: callbackId, inCoordinator: self)
            return
        }
        guard customChain.rpcUrls?.first != nil else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            delegate?.failed(withErrorMessage: R.string.localizable.addCustomChainErrorNoRpcNodeUrl(), withCallbackId: callbackId, inCoordinator: self)
            return
        }
        if let existingServer = ServersCoordinator.serversOrdered.first(where: { $0.chainID == customChainId }) {
            if config.enabledServers.contains(where: { $0.chainID == customChainId }) {
                if server.chainID == customChainId {
                    notifyAddCustomChainSucceededBecauseAlreadyActive(withCallbackId: callbackId)
                } else {
                    promptAndSwitchToExistingServerInBrowser(existingServer: existingServer, viewController: viewController, callbackID: callbackId)
                }
            } else {
                promptAndActivateExistingServer(existingServer: existingServer, inViewController: viewController, callbackID: callbackId)
            }
        } else {
            promptAndAddAndActivateServer(customChain: customChain, customChainId: customChainId, inViewController: viewController, callbackID: callbackId)
        }
    }

    private func promptAndActivateExistingServer(existingServer: RPCServer, inViewController viewController: UIViewController, callbackID: SwitchCustomChainCallbackId) {
        func runEnableChain() {
            let enableChain = EnableChain(existingServer, restartQueue: restartQueue, url: currentUrl)
            enableChain.delegate = self
            enableChain.run()
        }

        let configuration: SwitchChainRequestConfiguration = .promptAndActivateExistingServer(existingServer: existingServer)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action:
                runEnableChain()
            case .canceled:
                self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
            }
        }.cauterize()
    }

    private func promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int, inViewController viewController: UIViewController, callbackID: SwitchCustomChainCallbackId) {
        func runAddCustomChain(isTestnet: Bool) {
            let addCustomChain = AddCustomChain(customChain, analytics: analytics, isTestnet: isTestnet, restartQueue: restartQueue, url: currentUrl, operation: .add, chainNameFallback: R.string.localizable.addCustomChainUnnamed())
            self.addCustomChain = (chain: addCustomChain, callbackId: callbackID)
            addCustomChain.delegate = self
            addCustomChain.run()
        }

        let configuration: SwitchChainRequestConfiguration = .promptAndAddAndActivateServer(customChain: customChain, customChainId: customChainId)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action(let choice):
                switch choice {
                case 0:
                    runAddCustomChain(isTestnet: false)
                case 1:
                    runAddCustomChain(isTestnet: true)
                default:
                    self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
                }
            case .canceled:
                self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
            }
        }.cauterize()
    }

    private func promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer, viewController: UIViewController, callbackID: SwitchCustomChainCallbackId) {
        let configuration: SwitchChainRequestConfiguration = .promptAndSwitchToExistingServerInBrowser(existingServer: existingServer)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action:
                self.delegate?.switchBrowserToExistingServer(existingServer, callbackId: callbackID, url: self.currentUrl, inCoordinator: self)
            case .canceled:
                self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
            }
        }.cauterize()
    }

    //This is really only (and should only be) fired when the chain is already enabled and activated in browser. i.e. we are not supposed to have restarted the app UI or browser. It's a no-op. If DApps detect that the browser is already connected to the right chain, they might not even trigger this
    private func notifyAddCustomChainSucceededBecauseAlreadyActive(withCallbackId callbackId: SwitchCustomChainCallbackId) {
        delegate?.notifySuccessful(withCallbackId: callbackId, inCoordinator: self)
    }
}

extension DappRequestSwitchCustomChainCoordinator: EnableChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain) {
        delegate?.restartToEnableAndSwitchBrowserToServer(inCoordinator: self)
    }
}

extension DappRequestSwitchCustomChainCoordinator: AddCustomChainDelegate {

    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool> {
        UIAlertController.promptToUseUnresolvedExplorerURL(customChain: customChain, chainId: chainId, viewController: viewController)
    }

    //Don't need to notify browser/dapp since we are restarting UI
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        analytics.log(action: Analytics.Action.addCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "dapp"])
        guard self.addCustomChain != nil else {
            delegate?.cleanup(coordinator: self)
            return
        }
        delegate?.restartToAddEnableAndSwitchBrowserToServer(inCoordinator: self)
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        guard self.addCustomChain != nil else {
            delegate?.cleanup(coordinator: self)
            return
        }
        let dAppError: DAppError
        switch error {
        case .cancelled:
            dAppError = .cancelled
        case .missingBlockchainExplorerUrl, .invalidBlockchainExplorerUrl, .noRpcNodeUrl, .invalidChainId, .chainIdNotMatch, .unknown:
            dAppError = .nodeError(error.localizedDescription)
            UIAlertController.alert(title: nil, message: error.localizedDescription, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: viewController)

        }
        delegate?.failed(withError: dAppError, withCallbackId: callbackId, inCoordinator: self)
    }
}
