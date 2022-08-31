// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol DappRequestSwitchExistingChainCoordinatorDelegate: AnyObject {
    func notifySuccessful(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator)
    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator)
    func switchBrowserToExistingServer(_ server: RPCServer, callbackId: SwitchCustomChainCallbackId, url: URL?, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator)
    func userCancelled(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator)
    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator)
}

class DappRequestSwitchExistingChainCoordinator: NSObject, Coordinator {
    private let config: Config
    let server: RPCServer
    let callbackId: SwitchCustomChainCallbackId
    private let targetChain: WalletSwitchEthereumChainObject
    private let restartQueue: RestartTaskQueue
    private let analytics: AnalyticsLogger
    private let currentUrl: URL?
    private let viewController: UIViewController

    var coordinators: [Coordinator] = []
    weak var delegate: DappRequestSwitchExistingChainCoordinatorDelegate?

    init(config: Config, server: RPCServer, callbackId: SwitchCustomChainCallbackId, targetChain: WalletSwitchEthereumChainObject, restartQueue: RestartTaskQueue, analytics: AnalyticsLogger, currentUrl: URL?, inViewController viewController: UIViewController) {
        self.config = config
        self.server = server
        self.callbackId = callbackId
        self.targetChain = targetChain
        self.restartQueue = restartQueue
        self.analytics = analytics
        self.currentUrl = currentUrl
        self.viewController = viewController
    }

    func start() {
        guard let targetChainId = Int(chainId0xString: targetChain.chainId) else {
            delegate?.failed(withErrorMessage: R.string.localizable.switchChainErrorInvalidChainId(targetChain.chainId), withCallbackId: callbackId, inCoordinator: self)
            return
        }
        if let existingServer = ServersCoordinator.serversOrdered.first(where: { $0.chainID == targetChainId }) {
            if config.enabledServers.contains(where: { $0.chainID == targetChainId }) {
                if server.chainID == targetChainId {
                    notifySwitchChainSucceededBecauseAlreadyActive(withCallbackId: callbackId)
                } else {
                    promptAndSwitchToExistingServerInBrowser(existingServer: existingServer, viewController: viewController, callbackID: callbackId)
                }
            } else {
                promptAndActivateExistingServer(existingServer: existingServer, inViewController: viewController, callbackID: callbackId)
            }
        } else {
            delegate?.failed(withErrorMessage: R.string.localizable.switchChainErrorNotSupportedChainId(targetChain.chainId), withCallbackId: callbackId, inCoordinator: self)
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
    private func notifySwitchChainSucceededBecauseAlreadyActive(withCallbackId callbackId: SwitchCustomChainCallbackId) {
        delegate?.notifySuccessful(withCallbackId: callbackId, inCoordinator: self)
    }
}
extension DappRequestSwitchExistingChainCoordinator: EnableChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain) {
        delegate?.restartToEnableAndSwitchBrowserToServer(inCoordinator: self)
    }
}
