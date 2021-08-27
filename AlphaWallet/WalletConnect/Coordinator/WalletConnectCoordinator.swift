//
//  WalletConnectCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import WalletConnectSwift
import PromiseKit
import Result

typealias WalletConnectURL = WCURL
typealias WalletConnectSession = Session

enum SessionsToDisconnect {
    case allExcept(_ servers: [RPCServer])
    case all
}

typealias SessionsToURLServersMap = (sessions: [WalletConnectSession], urlToServer: [WCURL: RPCServer])

protocol WalletConnectCoordinatorDelegate: class, CanOpenURL {
    func universalScannerSelected(in coordinator: WalletConnectCoordinator)
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: WalletConnectCoordinator)
}

class WalletConnectCoordinator: NSObject, Coordinator {
    private lazy var server: WalletConnectServer = {
        let server = WalletConnectServer(wallet: sessions.anyValue.account.address)
        server.delegate = self
        return server
    }()

    private let navigationController: UINavigationController

    var coordinators: [Coordinator] = []
    var sessionsToURLServersMap: Subscribable<SessionsToURLServersMap> = .init((sessions: [], urlToServer: [:]))

    private let keystore: Keystore
    private let sessions: ServerDictionary<WalletSession>
    private let analyticsCoordinator: AnalyticsCoordinator
    private let config: Config
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>
    private weak var notificationAlertController: UIViewController?
    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
    }
    private weak var sessionsViewController: WalletConnectSessionsViewController?
    weak var delegate: WalletConnectCoordinatorDelegate?

    init(keystore: Keystore, sessions: ServerDictionary<WalletSession>, navigationController: UINavigationController, analyticsCoordinator: AnalyticsCoordinator, config: Config, nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>) {
        self.config = config
        self.sessions = sessions
        self.keystore = keystore
        self.navigationController = navigationController
        self.analyticsCoordinator = analyticsCoordinator
        self.nativeCryptoCurrencyPrices = nativeCryptoCurrencyPrices
        super.init()
        start()

        server.sessions.subscribe { [weak self, weak server] sessions in
            guard let strongSelf = self, let strongServer = server else { return }

            strongSelf.sessionsToURLServersMap.value = (sessions ?? [], strongServer.urlToServer)
        }
    }

    //NOTE: we are using disconnection to notify dapp that we get disconnect, in other case dapp still stay connected
    func disconnect(sessionsToDisconnect: SessionsToDisconnect) {

        let walletConnectSessions = UserDefaults.standard.walletConnectSessions
        let filteredSessions: [WalletConnectSession]

        switch sessionsToDisconnect {
        case .all:
            filteredSessions = walletConnectSessions
        case .allExcept(let servers):
            //NOTE: as we got stored session urls mapped with rpc servers we can filter urls and exclude unused session
            let sessionURLsToDisconnect = UserDefaults.standard.urlToServer.map {
                (key: $0.key, server: $0.value)
            }.filter {
                !servers.contains($0.server)
            }.map {
                $0.key
            }

            filteredSessions = walletConnectSessions.filter { sessionURLsToDisconnect.contains($0.url) }
        }

        for each in filteredSessions {
            try? server.disconnect(session: each)
        }
    }

    private func start() {
        for each in UserDefaults.standard.walletConnectSessions {
            try? server.reconnect(session: each)
        }
    }

    func openSession(url: WalletConnectURL) {
        navigationController.setNavigationBarHidden(false, animated: true)

        showSessions(state: .loading, navigationController: navigationController) {
            try? self.server.connect(url: url)
        }
    }

    func showSessionDetails(in navigationController: UINavigationController) {
        guard let sessions = server.sessions.value else { return }

        if sessions.count == 1 {
            let session = sessions[0]
            display(session: session, in: navigationController)
        } else {
            showSessions(state: .sessions, navigationController: navigationController)
        }
    }

    func showSessions() {
        navigationController.setNavigationBarHidden(false, animated: false)
        showSessions(state: .sessions, navigationController: navigationController)
    }

    private func showSessions(state: WalletConnectSessionsViewController.State, navigationController: UINavigationController, completion: @escaping (() -> Void) = {}) {
        if let viewController = sessionsViewController {
            viewController.configure(state: state)
            completion()
        } else {
            let viewController = WalletConnectSessionsViewController(sessionsToURLServersMap: sessionsToURLServersMap)
            viewController.delegate = self
            viewController.configure(state: state)

            sessionsViewController = viewController

            navigationController.pushViewController(viewController, animated: true, completion: completion)
        }
    }

    private func display(session: WalletConnectSession, in navigationController: UINavigationController) {
        let coordinator = WalletConnectSessionCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, server: server, session: session)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension WalletConnectCoordinator: WalletConnectSessionCoordinatorDelegate {
    func didDismiss(in coordinator: WalletConnectSessionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension WalletConnectCoordinator: WalletConnectServerDelegate {

    private func resetSessionsToRemoveLoadingIfNeeded() {
        if let viewController = sessionsViewController {
            viewController.set(state: .sessions)
        }
    }

    func server(_ server: WalletConnectServer, didConnect session: WalletConnectSession) {
        resetSessionsToRemoveLoadingIfNeeded()
    }

    func server(_ server: WalletConnectServer, action: WalletConnectServer.Action, request: WalletConnectRequest) {
        if let rpcServer = server.urlToServer[request.url] {
            let session = sessions[rpcServer]

            firstly {
                Promise<Void> { seal in
                    switch session.account.type {
                    case .real:
                        seal.fulfill(())
                    case .watch:
                        seal.reject(PMKError.cancelled)
                    }
                }
            }.then { _ -> Promise<WalletConnectServer.Callback> in
                let account = session.account.address
                switch action.type {
                case .signTransaction(let transaction):
                    return self.executeTransaction(session: session, callbackID: action.id, url: action.url, transaction: transaction, type: .sign)
                case .sendTransaction(let transaction):
                    return self.executeTransaction(session: session, callbackID: action.id, url: action.url, transaction: transaction, type: .signThenSend)
                case .signMessage(let hexMessage):
                    return self.signMessage(with: .message(hexMessage.toHexData), account: account, callbackID: action.id, url: action.url)
                case .signPersonalMessage(let hexMessage):
                    return self.signMessage(with: .personalMessage(hexMessage.toHexData), account: account, callbackID: action.id, url: action.url)
                case .signTypedMessageV3(let typedData):
                    return self.signMessage(with: .eip712v3And4(typedData), account: account, callbackID: action.id, url: action.url)
                case .typedMessage(let typedData):
                    return self.signMessage(with: .typedMessage(typedData), account: account, callbackID: action.id, url: action.url)
                case .sendRawTransaction(let raw):
                    return self.sendRawTransaction(session: session, rawTransaction: raw, callbackID: action.id, url: action.url)
                case .getTransactionCount:
                    return self.getTransactionCount(session: session, callbackID: action.id, url: action.url)
                case .unknown:
                    throw PMKError.cancelled
                }
            }.done { callback in
                try? server.fulfill(callback, request: request)
            }.catch { _ in
                server.reject(request)
            }
        } else {
            server.reject(request)
        }
    }

    private func signMessage(with type: SignMessageType, account: AlphaWallet.Address, callbackID id: WalletConnectRequestID, url: WalletConnectURL) -> Promise<WalletConnectServer.Callback> {
        firstly {
            SignMessageCoordinator.promise(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .walletConnect)
        }.map { data -> WalletConnectServer.Callback in
            return .init(id: id, url: url, value: data)
        }
    }

    private func executeTransaction(session: WalletSession, callbackID id: WalletConnectRequestID, url: WalletConnectURL, transaction: UnconfirmedTransaction, type: ConfirmType) -> Promise<WalletConnectServer.Callback> {
        guard let rpcServer = server.urlToServer[url] else { return Promise(error: WalletConnectError.connectionInvalid) }
        let ethPrice = nativeCryptoCurrencyPrices[rpcServer]
        let configuration: TransactionConfirmationConfiguration = .walletConnect(confirmType: type, keystore: keystore, ethPrice: ethPrice)
        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, source: .walletConnect, didSendTransactionClosure: { [weak self] tx in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didSendTransaction(tx, inCoordinator: strongSelf)
            })
        }.map { data -> WalletConnectServer.Callback in
            switch data {
            case .signedTransaction(let data):
                return .init(id: id, url: url, value: data)
            case .sentTransaction(let transaction):
                let data = Data(_hex: transaction.id)
                return .init(id: id, url: url, value: data)
            case .sentRawTransaction:
                //NOTE: Doesn't support sentRawTransaction for TransactionConfirmationCoordinator, for it we are using another function
                throw PMKError.cancelled
            }
        }.map { callback in
            //NOTE: Show transaction in progress only for sent transactions
            switch type {
            case .sign:
                break
            case .signThenSend:
                TransactionInProgressCoordinator.promise(self.navigationController, coordinator: self).done { _ in
                    //no op
                }.cauterize()
            }
            return callback
        }.recover { error -> Promise<WalletConnectServer.Callback> in
            if case DAppError.cancelled = error {
                //no op
            } else {
                self.navigationController.displayError(error: error)
            }
            throw error
        }
    }

    private var presentationViewController: UIViewController {
        guard let keyWindow = UIApplication.shared.keyWindow else { return navigationController }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            return controller
        } else {
            return navigationController
        }
    }

    func server(_ server: WalletConnectServer, didFail error: Error) {
        let errorMessage = R.string.localizable.walletConnectFailureTitle()

        if let presentedController = notificationAlertController {
            presentedController.dismiss(animated: true) { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.notificationAlertController = strongSelf.presentationViewController.displaySuccess(message: errorMessage)
            }
        } else {
            notificationAlertController = presentationViewController.displaySuccess(message: errorMessage)
        }

        resetSessionsToRemoveLoadingIfNeeded()
    }

    func server(_ server: WalletConnectServer, shouldConnectFor connection: WalletConnectConnection, completion: @escaping (WalletConnectServer.ConnectionChoice) -> Void) {
        firstly {
            WalletConnectToSessionCoordinator.promise(navigationController, coordinator: self, connection: connection, serverChoices: serverChoices, analyticsCoordinator: analyticsCoordinator, config: config)
        }.done { choise in
            completion(choise)
        }.catch { _ in
            completion(.cancel)
        }.finally {
            self.resetSessionsToRemoveLoadingIfNeeded()
        }
    }

    private func sendRawTransaction(session: WalletSession, rawTransaction: String, callbackID id: WalletConnectRequestID, url: WalletConnectURL) -> Promise<WalletConnectServer.Callback> {
        return firstly {
            showSignRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: rawTransaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: DAppError.cancelled) }

            let coordinator = SendTransactionCoordinator(session: session, keystore: self.keystore, confirmType: .sign, config: self.config)
            return coordinator.send(rawTransaction: rawTransaction)
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw PMKError.cancelled
            case .sentRawTransaction(let transactionId, _):
                let data = Data(_hex: transactionId)
                return .init(id: id, url: url, value: data)
            }
        }.then { callback -> Promise<WalletConnectServer.Callback> in
            return UINotificationFeedbackGenerator.showFeedbackPromise(value: callback, feedbackType: .success)
        }
    }

    private func getTransactionCount(session: WalletSession, callbackID id: WalletConnectRequestID, url: WalletConnectURL) -> Promise<WalletConnectServer.Callback> {
        firstly {
            GetNextNonce(server: session.server, wallet: session.account.address).promise()
        }.map {
            if let data = Data(fromHexEncodedString: String(format: "%02X", $0)) {
                return .init(id: id, url: url, value: data)
            } else {
                throw PMKError.badInput
            }
        }
    }

    private func showSignRawTransaction(title: String, message: String) -> Promise<Bool> {
        return Promise { seal in
            let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet

            let alertViewController = UIAlertController(title: title, message: message, preferredStyle: style)
            let startAction = UIAlertAction(title: R.string.localizable.oK(), style: .default) { _ in
                seal.fulfill(true)
            }

            let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
                seal.fulfill(false)
            }

            alertViewController.addAction(startAction)
            alertViewController.addAction(cancelAction)

            navigationController.present(alertViewController, animated: true)
        }
    }
}

extension WalletConnectCoordinator: WalletConnectSessionsViewControllerDelegate {

    func qrCodeSelected(in viewController: WalletConnectSessionsViewController) {
        delegate?.universalScannerSelected(in: self)
    }

    func didClose(in viewController: WalletConnectSessionsViewController) {
        //NOTE: even if we haven't sessions view controller pushed to navigation stack, we need to make sure that root NavigationBar will be hidden
        navigationController.setNavigationBarHidden(true, animated: false)

        guard let navigationController = viewController.navigationController else { return }
        navigationController.popViewController(animated: true)
    }

    func didSelect(session: WalletConnectSession, in viewController: WalletConnectSessionsViewController) {
        guard let navigationController = viewController.navigationController else { return }

        display(session: session, in: navigationController)
    }
}

extension WalletConnectCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
