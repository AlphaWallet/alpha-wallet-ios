// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation
import Combine
import AlphaWalletCore

enum SwitchCustomChainOperation {
    case notifySuccessful
    case restartToEnableAndSwitchBrowserToServer
    case restartToAddEnableAndSwitchBrowserToServer
    case switchBrowserToExistingServer(_ server: RPCServer, url: URL?)
}

class DappRequestSwitchCustomChainCoordinator: NSObject, Coordinator {
    private var addCustomChain: AddCustomChain?
    private let config: Config
    private let server: RPCServer
    private let customChain: WalletAddEthereumChainObject
    private let restartQueue: RestartTaskQueue
    private let analytics: AnalyticsLogger
    private let currentUrl: URL?
    private let viewController: UIViewController
    private let networkService: NetworkService
    var coordinators: [Coordinator] = []

    private let subject = PassthroughSubject<SwitchCustomChainOperation, PromiseError>()

    init(config: Config,
         server: RPCServer,
         customChain: WalletAddEthereumChainObject,
         restartQueue: RestartTaskQueue,
         analytics: AnalyticsLogger,
         currentUrl: URL?,
         viewController: UIViewController,
         networkService: NetworkService) {

        self.networkService = networkService
        self.config = config
        self.server = server
        self.customChain = customChain
        self.restartQueue = restartQueue
        self.analytics = analytics
        self.currentUrl = currentUrl
        self.viewController = viewController
    }

    func start() -> AnyPublisher<SwitchCustomChainOperation, PromiseError> {
        guard let customChainId = Int(chainId0xString: customChain.chainId) else {
            return .fail(PromiseError(error: DAppError.nodeError(R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId))))
        }
        guard customChain.rpcUrls?.first != nil else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            return .fail(PromiseError(error: DAppError.nodeError(R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId))))
        }
        if let existingServer = ServersCoordinator.serversOrdered.first(where: { $0.chainID == customChainId }) {
            if config.enabledServers.contains(where: { $0.chainID == customChainId }) {
                if server.chainID == customChainId {
                    return .just(.notifySuccessful)
                } else {
                    promptAndSwitchToExistingServerInBrowser(existingServer: existingServer, viewController: viewController)
                }
            } else {
                promptAndActivateExistingServer(existingServer: existingServer, inViewController: viewController)
            }
        } else {
            promptAndAddAndActivateServer(customChain: customChain, customChainId: customChainId, inViewController: viewController)
        }

        return subject.eraseToAnyPublisher()
    }

    private func promptAndActivateExistingServer(existingServer: RPCServer, inViewController viewController: UIViewController) {
        func runEnableChain() {
            let enableChain = EnableChain(existingServer, restartQueue: restartQueue, url: currentUrl)
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
                subject.send(completion: .failure(PromiseError(error: DAppError.cancelled)))
            }
        }.cauterize()
    }

    private func promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int, inViewController viewController: UIViewController) {
        func runAddCustomChain(isTestnet: Bool) {
            let addCustomChain = AddCustomChain(
                customChain,
                isTestnet: isTestnet,
                restartQueue: restartQueue,
                url: currentUrl,
                operation: .add,
                chainNameFallback: R.string.localizable.addCustomChainUnnamed(),
                networkService: networkService,
                analytics: analytics)

            self.addCustomChain = addCustomChain
            addCustomChain.delegate = self
            addCustomChain.run()
        }

        let configuration: SwitchChainRequestConfiguration = .promptAndAddAndActivateServer(customChain: customChain, customChainId: customChainId)
        SwitchChainRequestViewController.promise(viewController, configuration: configuration).done { [subject] result in
            // NOTE: here we pretty sure that there is only one action
            switch result {
            case .action(let choice):
                switch choice {
                case 0:
                    runAddCustomChain(isTestnet: false)
                case 1:
                    runAddCustomChain(isTestnet: true)
                default:
                    subject.send(completion: .failure(PromiseError(error: DAppError.cancelled)))
                }
            case .canceled:
                subject.send(completion: .failure(PromiseError(error: DAppError.cancelled)))
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
                subject.send(completion: .failure(PromiseError(error: DAppError.cancelled)))
            }
        }.cauterize()
    }
}

extension DappRequestSwitchCustomChainCoordinator: EnableChainDelegate {
    //Don't need to notify browser/dapp since we are restarting UI
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain) {
        subject.send(.restartToEnableAndSwitchBrowserToServer)
        subject.send(completion: .finished)
    }
}

extension DappRequestSwitchCustomChainCoordinator: AddCustomChainDelegate {

    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> AnyPublisher<Bool, Never> {
        UIAlertController.promptToUseUnresolvedExplorerURL(customChain: customChain, chainId: chainId, viewController: viewController)
    }

    //Don't need to notify browser/dapp since we are restarting UI
    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        analytics.log(action: Analytics.Action.addCustomChain, properties: [Analytics.Properties.addCustomChainType.rawValue: "dapp"])
        guard self.addCustomChain != nil else {
            subject.send(completion: .finished)
            return
        }

        subject.send(.restartToAddEnableAndSwitchBrowserToServer)
        subject.send(completion: .finished)
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        guard self.addCustomChain != nil else {
            subject.send(completion: .finished)
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

        subject.send(completion: .failure(.some(error: dAppError)))
    }
}
