// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol SwitchCustomChainCoordinatorDelegate: class {
    func notifySuccessful(withCallbackId callbackId: Int, inCoordinator coordinator: SwitchCustomChainCoordinator)
    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: SwitchCustomChainCoordinator)
    func restartToAddEnableAAndSwitchBrowserToServer(inCoordinator coordinator: SwitchCustomChainCoordinator)
    func switchBrowserToExistingServer(_ server: RPCServer, url: URL?, inCoordinator coordinator: SwitchCustomChainCoordinator)
    func userCancelled(withCallbackId callbackId: Int, inCoordinator coordinator: SwitchCustomChainCoordinator)
    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: Int, inCoordinator coordinator: SwitchCustomChainCoordinator)
    func failed(withError error: DAppError, withCallbackId callbackId: Int, inCoordinator coordinator: SwitchCustomChainCoordinator)
    //This might not always been called. We call it when there's no other delegate function to call to inform the delegate to remove this coordinator
    func cleanup(coordinator: SwitchCustomChainCoordinator)
}

class SwitchCustomChainCoordinator: NSObject, Coordinator {
    private var addCustomChain: (chain: AddCustomChain, callbackId: Int)?
    private let config: Config
    private let server: RPCServer
    private let callbackId: Int
    private let customChain: WalletAddEthereumChainObject
    private let restartQueue: RestartTaskQueue
    private let currentUrl: URL?
    private let viewController: UIViewController

    var coordinators: [Coordinator] = []
    weak var delegate: SwitchCustomChainCoordinatorDelegate?

    init(config: Config, server: RPCServer, callbackId: Int, customChain: WalletAddEthereumChainObject, restartQueue: RestartTaskQueue, currentUrl: URL?, inViewController viewController: UIViewController) {
        self.config = config
        self.server = server
        self.callbackId = callbackId
        self.customChain = customChain
        self.restartQueue = restartQueue
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
                        let enableChain = EnableChain(existingServer, restartQueue: restartQueue, url: currentUrl)
                        enableChain.delegate = self
                        enableChain.run()
                    } else {
                        delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
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
                        let addCustomChain = AddCustomChain(customChain, isTestnet: isTestnet, restartQueue: restartQueue, url: currentUrl)
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
                        delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
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
                        delegate?.switchBrowserToExistingServer(existingServer, url: currentUrl, inCoordinator: self)
                    } else {
                        delegate?.userCancelled(withCallbackId: callbackID, inCoordinator: self)
                    }
                })
    }

    //This is really only (and should only be) fired when the chain is already enabled and activated in browser. i.e. we are not supposed to have restarted the app UI or browser. It's a no-op. If DApps detect that the browser is already connected to the right chain, they might not even trigger this
    private func notifyAddCustomChainSucceededBecauseAlreadyActive(withCallbackId callbackId: Int) {
        delegate?.notifySuccessful(withCallbackId: callbackId, inCoordinator: self)
    }
}

extension SwitchCustomChainCoordinator: EnableChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain) {
        delegate?.restartToEnableAndSwitchBrowserToServer(inCoordinator: self)
    }
}

extension SwitchCustomChainCoordinator: AddCustomChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        guard self.addCustomChain != nil else {
            delegate?.cleanup(coordinator: self)
            return
        }
        delegate?.restartToAddEnableAAndSwitchBrowserToServer(inCoordinator: self)
    }

    func notifyAddCustomChainFailed(error: DAppError, in addCustomChain: AddCustomChain) {
        guard self.addCustomChain != nil else {
            delegate?.cleanup(coordinator: self)
            return
        }
        delegate?.failed(withError: error, withCallbackId: callbackId, inCoordinator: self)
    }
}