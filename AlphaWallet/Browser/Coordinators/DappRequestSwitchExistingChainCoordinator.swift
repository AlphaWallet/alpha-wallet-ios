// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import AlphaWalletCore
import Combine

enum SwitchExistingChainOperation {
    case notifySuccessful
    case restartToEnableAndSwitchBrowserToServer
    case switchBrowserToExistingServer(_ server: RPCServer, url: URL?)
}

class DappRequestSwitchExistingChainCoordinator: NSObject, Coordinator {
    private let config: Config
    private let server: RPCServer
    private let targetChain: WalletSwitchEthereumChainObject
    private let restartHandler: RestartQueueHandler
    private let analytics: AnalyticsLogger
    private let currentUrl: URL?
    private let viewController: UIViewController
    private let subject = PassthroughSubject<SwitchExistingChainOperation, PromiseError>()
    private let serversProvider: ServersProvidable

    var coordinators: [Coordinator] = []

    init(config: Config,
         server: RPCServer,
         targetChain: WalletSwitchEthereumChainObject,
         restartHandler: RestartQueueHandler,
         analytics: AnalyticsLogger,
         currentUrl: URL?,
         serversProvider: ServersProvidable,
         viewController: UIViewController) {

        self.serversProvider = serversProvider
        self.config = config
        self.server = server
        self.targetChain = targetChain
        self.restartHandler = restartHandler
        self.analytics = analytics
        self.currentUrl = currentUrl
        self.viewController = viewController
    }

    func start() -> AnyPublisher<SwitchExistingChainOperation, PromiseError> {
        guard let targetChainId = Int(chainId0xString: targetChain.chainId) else {
            return .fail(PromiseError(error: JsonRpcError.internalError(message: R.string.localizable.switchChainErrorInvalidChainId(targetChain.chainId))))
        }
        if let existingServer = ServersCoordinator.serversOrdered.first(where: { $0.chainID == targetChainId }) {
            if serversProvider.enabledServers.contains(where: { $0.chainID == targetChainId }) {
                if server.chainID == targetChainId {
                    //This is really only (and should only be) fired when the chain is already enabled and activated in browser. i.e. we are not supposed to have restarted the app UI or browser. It's a no-op. If DApps detect that the browser is already connected to the right chain, they might not even trigger this
                    return .just(.notifySuccessful)
                } else {
                    promptAndSwitchToExistingServerInBrowser(existingServer: existingServer, viewController: viewController)
                }
            } else {
                promptAndActivateExistingServer(existingServer: existingServer, inViewController: viewController)
            }
        } else {
            return .fail(PromiseError(error: JsonRpcError.unsupportedChain(chainId: targetChain.chainId)))
        }

        return subject.eraseToAnyPublisher()
    }

    private func promptAndActivateExistingServer(existingServer: RPCServer, inViewController viewController: UIViewController) {
        func runEnableChain() {
            let enableChain = EnableChain(existingServer, restartHandler: restartHandler, url: currentUrl)
            enableChain.delegate = self
            enableChain.run()
        }

        let configuration: SwitchChainRequestConfiguration = .promptAndActivateExistingServer(existingServer: existingServer)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { [subject] result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action:
                runEnableChain()
            case .canceled:
                subject.send(completion: .failure(PromiseError(error: JsonRpcError.requestRejected)))
            }
        }.cauterize()
    }

    private func promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer, viewController: UIViewController) {
        let configuration: SwitchChainRequestConfiguration = .promptAndSwitchToExistingServerInBrowser(existingServer: existingServer)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { [subject] result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action:
                subject.send(.switchBrowserToExistingServer(existingServer, url: self.currentUrl))
                subject.send(completion: .finished)
            case .canceled:
                subject.send(completion: .failure(PromiseError(error: JsonRpcError.requestRejected)))
            }
        }.cauterize()
    }
}
extension DappRequestSwitchExistingChainCoordinator: EnableChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain) {
        subject.send(.restartToEnableAndSwitchBrowserToServer)
        subject.send(completion: .finished)
    }
}
