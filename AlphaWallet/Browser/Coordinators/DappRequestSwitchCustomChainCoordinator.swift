// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol DappRequestSwitchCustomChainCoordinatorDelegate: class {
    func notifySuccessful(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func switchBrowserToExistingServer(_ server: RPCServer, url: URL?, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func userCancelled(withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    func failed(withError error: DAppError, withCallbackId callbackId: Int, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator)
    //This might not always been called. We call it when there's no other delegate function to call to inform the delegate to remove this coordinator
    func cleanup(coordinator: DappRequestSwitchCustomChainCoordinator)
}

class DappRequestSwitchCustomChainCoordinator: NSObject, Coordinator {
    private var addCustomChain: (chain: AddCustomChain, callbackId: Int)?
    private let config: Config
    private let server: RPCServer
    private let callbackId: Int
    private let customChain: WalletAddEthereumChainObject
    private let restartQueue: RestartTaskQueue
    private let analyticsCoordinator: AnalyticsCoordinator
    private let currentUrl: URL?
    private let viewController: UIViewController

    var coordinators: [Coordinator] = []
    weak var delegate: DappRequestSwitchCustomChainCoordinatorDelegate?

    init(config: Config, server: RPCServer, callbackId: Int, customChain: WalletAddEthereumChainObject, restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator, currentUrl: URL?, inViewController viewController: UIViewController) {
        self.config = config
        self.server = server
        self.callbackId = callbackId
        self.customChain = customChain
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
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

    private func promptAndActivateExistingServer(existingServer: RPCServer, inViewController viewController: UIViewController, callbackID: Int) {
        let title = R.string.localizable.addCustomChainEnableExisting(existingServer.displayName, existingServer.chainID)
        UIAlertController.alert(title: title,
                message: nil,
                alertButtonTitles: [R.string.localizable.oK(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: viewController,
                completion: { [self] choice in
                    if choice == 0 {
                        let enableChain = EnableChain(existingServer, restartQueue: self.restartQueue, url: self.currentUrl)
                        enableChain.delegate = self
                        enableChain.run()
                    } else {
                        self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
                    }
                })
    }

    private func promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int, inViewController viewController: UIViewController, callbackID: Int) {
        let title = R.string.localizable.addCustomChainAddAndSwitch(customChain.chainName ?? R.string.localizable.addCustomChainUnnamed(), customChainId)
        UIAlertController.alert(title: title,
                message: nil,
                alertButtonTitles: [R.string.localizable.settingsEnabledNetworksMainnet(), R.string.localizable.settingsEnabledNetworksTestnet(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .destructive, .cancel],
                viewController: viewController,
                completion: { [self] choice in
                    func runAddCustomChain(isTestnet: Bool) {
                        let addCustomChain = AddCustomChain(customChain, isTestnet: isTestnet, restartQueue: self.restartQueue, url: self.currentUrl)
                        self.addCustomChain = (chain: addCustomChain, callbackId: callbackID)
                        addCustomChain.delegate = self
                        addCustomChain.run()
                    }
                    switch choice {
                    case 0:
                        runAddCustomChain(isTestnet: false)
                    case 1:
                        runAddCustomChain(isTestnet: true)
                    default:
                        self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
                    }
                })
    }

    private func promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer, viewController: UIViewController, callbackID: Int) {
        let title = R.string.localizable.addCustomChainSwitchToExisting(existingServer.displayName, existingServer.chainID)
        UIAlertController.alert(title: title,
                message: nil,
                alertButtonTitles: [R.string.localizable.oK(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: viewController,
                completion: { [self] choice in
                    if choice == 0 {
                        self.delegate?.switchBrowserToExistingServer(existingServer, url: self.currentUrl, inCoordinator: self)
                    } else {
                        self.delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
                    }
                })
    }

    //This is really only (and should only be) fired when the chain is already enabled and activated in browser. i.e. we are not supposed to have restarted the app UI or browser. It's a no-op. If DApps detect that the browser is already connected to the right chain, they might not even trigger this
    private func notifyAddCustomChainSucceededBecauseAlreadyActive(withCallbackId callbackId: Int) {
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
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        analyticsCoordinator.log(action: Analytics.Action.addCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "dapp"])
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
        case .others(let message):
            dAppError = .nodeError(message)
            UIAlertController.alert(title: nil, message: message, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: viewController)
        }
        delegate?.failed(withError: dAppError, withCallbackId: callbackId, inCoordinator: self)
    }
}
