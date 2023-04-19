// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
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
    private let restartHandler: RestartQueueHandler
    private let analytics: AnalyticsLogger
    private let currentUrl: URL?
    private let viewController: UIViewController
    private let networkService: NetworkService
    private let serversProvider: ServersProvidable
    var coordinators: [Coordinator] = []

    private let subject = PassthroughSubject<SwitchCustomChainOperation, PromiseError>()

    init(config: Config,
         server: RPCServer,
         customChain: WalletAddEthereumChainObject,
         restartHandler: RestartQueueHandler,
         analytics: AnalyticsLogger,
         currentUrl: URL?,
         serversProvider: ServersProvidable,
         viewController: UIViewController,
         networkService: NetworkService) {

        self.serversProvider = serversProvider
        self.networkService = networkService
        self.config = config
        self.server = server
        self.customChain = customChain
        self.restartHandler = restartHandler
        self.analytics = analytics
        self.currentUrl = currentUrl
        self.viewController = viewController
    }

    func start() -> AnyPublisher<SwitchCustomChainOperation, PromiseError> {
        guard let customChainId = Int(chainId0xString: customChain.chainId) else {
            return .fail(PromiseError(error: JsonRpcError.internalError(message: R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId))))
        }
        guard customChain.rpcUrls?.first != nil else {
            //Not to spec since RPC URLs are optional according to EIP3085, but it is so much easier to assume it's needed, and quite useless if it isn't provided
            return .fail(PromiseError(error: JsonRpcError.internalError(message: R.string.localizable.addCustomChainErrorInvalidChainId(customChain.chainId))))
        }
        if let existingServer = ServersCoordinator.serversOrdered.first(where: { $0.chainID == customChainId }) {
            if serversProvider.enabledServers.contains(where: { $0.chainID == customChainId }) {
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

    private func promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int, inViewController viewController: UIViewController) {
        func runAddCustomChain(isTestnet: Bool) {
            let addCustomChain = AddCustomChain(
                customChain,
                isTestnet: isTestnet,
                restartHandler: restartHandler,
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
                    subject.send(completion: .failure(PromiseError(error: JsonRpcError.requestRejected)))
                }
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
        let jsonRpcError: JsonRpcError
        switch error {
        case .cancelled:
            jsonRpcError = .requestRejected
        case .missingBlockchainExplorerUrl, .invalidBlockchainExplorerUrl, .noRpcNodeUrl, .invalidChainId, .chainIdNotMatch, .unknown:
            jsonRpcError = JsonRpcError.internalError(message: error.localizedDescription)
            UIAlertController.alert(title: nil, message: error.localizedDescription, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: viewController)

        }

        subject.send(completion: .failure(.some(error: jsonRpcError)))
    }
}
