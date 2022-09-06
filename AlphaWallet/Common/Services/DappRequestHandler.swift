//
//  DappRequestHandler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.03.2022.
//

import Foundation
import AlphaWalletFoundation

protocol DappRequestHandlerDelegate: class {
    func processRestartQueueAndRestartUI(reason: RestartReason)
}

extension ActiveWalletCoordinator {
    /// Wraps DappRequestSwitchCustomChainCoordinatorDelegate and DappRequestSwitchExistingChainCoordinatorDelegate to reduce in coordinator size
    class DappRequestHandler: Coordinator {
        private let walletConnectCoordinator: WalletConnectCoordinator
        private var dappBrowserCoordinator: DappBrowserCoordinator

        weak var delegate: DappRequestHandlerDelegate?
        var coordinators: [Coordinator] = []

        init(walletConnectCoordinator: WalletConnectCoordinator, dappBrowserCoordinator: DappBrowserCoordinator) {
            self.walletConnectCoordinator = walletConnectCoordinator
            self.dappBrowserCoordinator = dappBrowserCoordinator
        }

        private func processRestartQueueAndRestartUI(reason: RestartReason) {
            delegate?.processRestartQueueAndRestartUI(reason: reason)
        }
    }
}
extension ActiveWalletCoordinator.DappRequestHandler: DappRequestSwitchCustomChainCoordinatorDelegate {

    func notifySuccessful(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            let callback = DappCallback(id: callbackId, value: .walletAddEthereumChain)
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .success(callback))
        case .walletConnect(let request):
            try? walletConnectCoordinator.responseServerChangeSucceed(request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: coordinator.server)
        }
        removeCoordinator(coordinator)
    }

    func switchBrowserToExistingServer(_ server: RPCServer, callbackId: SwitchCustomChainCallbackId, url: URL?, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        dappBrowserCoordinator.switch(toServer: server, url: url)

        switch callbackId {
        case .dapp:
            break
        case .walletConnect(let request):
            try? walletConnectCoordinator.responseServerChangeSucceed(request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: server)
        }
        removeCoordinator(coordinator)
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
        switch coordinator.callbackId {
        case .dapp:
            break
        case .walletConnect(let request):
            try? walletConnectCoordinator.responseServerChangeSucceed(request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: coordinator.server)
        }
        removeCoordinator(coordinator)
    }
    
    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
        switch coordinator.callbackId {
        case .dapp:
            break
        case .walletConnect(let request):
            try? walletConnectCoordinator.responseServerChangeSucceed(request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: coordinator.server)
        }
        removeCoordinator(coordinator)
    }

    func userCancelled(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .failure(DAppError.cancelled))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .init(error: .requestRejected), request: request)
        }
        removeCoordinator(coordinator)
    }

    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            let error = DAppError.nodeError(errorMessage)
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .failure(error))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .init(code: 0, message: errorMessage), request: request)
        }
        removeCoordinator(coordinator)
    }

    func failed(withError error: DAppError, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchCustomChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .failure(error))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .init(error: .requestRejected), request: request)
        }
        removeCoordinator(coordinator)
    }

    func cleanup(coordinator: DappRequestSwitchCustomChainCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator.DappRequestHandler: DappRequestSwitchExistingChainCoordinatorDelegate {

    func notifySuccessful(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            let callback = DappCallback(id: callbackId, value: .walletSwitchEthereumChain)
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .success(callback))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .value(nil), request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: coordinator.server)
        }

        removeCoordinator(coordinator)
    }

    func switchBrowserToExistingServer(_ server: RPCServer, callbackId: SwitchCustomChainCallbackId, url: URL?, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        dappBrowserCoordinator.switch(toServer: server, url: url)
        switch callbackId {
        case .dapp:
            break
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .value(nil), request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: server)
        }
        removeCoordinator(coordinator)
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
        switch coordinator.callbackId {
        case .dapp:
            break
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .value(nil), request: request)
            try? walletConnectCoordinator.notifyUpdateServers(request: request, server: coordinator.server)
        }
        removeCoordinator(coordinator)
    }
    func userCancelled(withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .failure(DAppError.cancelled))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .init(error: .requestRejected), request: request)
        }
        removeCoordinator(coordinator)
    }

    func failed(withErrorMessage errorMessage: String, withCallbackId callbackId: SwitchCustomChainCallbackId, inCoordinator coordinator: DappRequestSwitchExistingChainCoordinator) {
        switch callbackId {
        case .dapp(let callbackId):
            let error = DAppError.nodeError(errorMessage)
            dappBrowserCoordinator.notifyFinish(callbackID: callbackId, value: .failure(error))
        case .walletConnect(let request):
            try? walletConnectCoordinator.respond(response: .init(error: .requestRejected), request: request)
        }
        removeCoordinator(coordinator)
    }
}
