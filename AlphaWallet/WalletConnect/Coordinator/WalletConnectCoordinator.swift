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

class WalletConnectCoordinator: NSObject, Coordinator {
    enum Action {
        case startWalletConnectSession(WalletConnectURL)
        case openSessionDetails(navigationController: UINavigationController)
    }

    private lazy var server: WalletConnectServer = {
        let server = WalletConnectServer(configuration: configuration, config: config)
        server.delegate = self
        return server
    }()

    private let navigationController: UINavigationController

    var coordinators: [Coordinator] = []
    var connection: Subscribable<WalletConnectServerConnection> {
        return server.connection
    }
    private var session: WalletSession {
        return sessions[configuration.rpcServer]
    }
    private let keystore: Keystore
    private var configuration: WalletConnectServer.Configuration
    private let analyticsCoordinator: AnalyticsCoordinator?
    private let config: Config
    var sessions: ServerDictionary<WalletSession> = .init()

    init(keystore: Keystore, configuration: WalletConnectServer.Configuration, navigationController: UINavigationController, analyticsCoordinator: AnalyticsCoordinator?, config: Config) {
        self.config = config
        self.configuration = configuration
        self.keystore = keystore
        self.navigationController = navigationController
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        if let session = UserDefaults.standard.lastSession {
            try? server.reconnect(session: session)
        }
    }

    func set(configuration conf: WalletConnectServer.Configuration) {
        disconnect()

        configuration = conf
        server.set(configuration: conf)
    }

    private func disconnect() {
        switch server.connection.value {
        case .connected(let session):
            try? server.disconnect(session: session)
        case .none, .disconnected:
            break
        }
    }

    func perform(_ action: Action) {
        switch action {
        case .startWalletConnectSession(let url):
            disconnect()

            try? server.connect(url: url)
        case .openSessionDetails(let navigationController):
            switch server.connection.value {
            case .connected(let session):
                let coordinator = WalletConnectSessionCoordinator(navigationController: navigationController, server: server, session: session)
                coordinator.delegate = self
                coordinator.start()

                addCoordinator(coordinator)
            case .disconnected, .none:
                break
            }
        }
    }
}

extension WalletConnectCoordinator: WalletConnectSessionCoordinatorDelegate {

    func didDismiss(in coordinator: WalletConnectSessionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension WalletConnectCoordinator: WalletConnectServerDelegate {

    func server(_ server: WalletConnectServer, action: WalletConnectServer.Action, request: WalletConnectRequest) {
        firstly {
            return Promise<AlphaWallet.Address> { seal in
                if case .real(let account) = session.account.type {
                    seal.fulfill(account)
                } else {
                    seal.reject(PMKError.cancelled)
                }
            }
        }.then { account -> Promise<WalletConnectServer.Callback> in
            switch action.type {
            case .signTransaction(let transaction):
                return self.executeTransaction(account: account, callbackID: action.id, url: action.url, transaction: transaction, type: .sign)
            case .sendTransaction(let transaction):
                return self.executeTransaction(account: account, callbackID: action.id, url: action.url, transaction: transaction, type: .signThenSend)
            case .signMessage(let hexMessage):
                return self.signMessage(with: .message(hexMessage.toHexData), account: account, callbackID: action.id, url: action.url)
            case .signPersonalMessage(let hexMessage):
                return self.signMessage(with: .personalMessage(hexMessage.toHexData), account: account, callbackID: action.id, url: action.url)
            case .signTypedMessage(let typedData):
                return self.signMessage(with: .eip712(typedData), account: account, callbackID: action.id, url: action.url)
            case .sendRawTransaction(let raw):
                return self.send(rawTransaction: raw, callbackID: action.id, url: action.url)
            case .getTransactionCount:
                //NOTE: there is case like in example client app when client whants to get nonce first and then send transaction,
                //here i suppose we need to show UI to user to allow to enter this nonce value
                let data = "0x117".toHexData
                return .value(.init(id: action.id, url: action.url, value: .getTransactionCount(data)))
            case .unknown:
                throw PMKError.cancelled
            }
        }.done { callback in
            try? server.fullfill(callback, request: request)
        }.catch { _ in
            server.reject(request)
        }
    }

    private func signMessage(with type: SignMessageType, account: AlphaWallet.Address, callbackID id: WalletConnectRequestID, url: WalletConnectURL) -> Promise<WalletConnectServer.Callback> {
        return SignMessageCoordinator.promise(navigationController, keystore: keystore, coordinator: self, signType: type, account: account).map { data -> WalletConnectServer.Callback in
            switch type {
            case .message:
                return .init(id: id, url: url, value: .signMessage(data))
            case .personalMessage:
                return .init(id: id, url: url, value: .signPersonalMessage(data))
            case .typedMessage, .eip712:
                return .init(id: id, url: url, value: .signTypedMessage(data))
            }
        }
    }

    private func executeTransaction(account: AlphaWallet.Address, callbackID id: WalletConnectRequestID, url: WalletConnectURL, transaction: UnconfirmedTransaction, type: ConfirmType) -> Promise<WalletConnectServer.Callback> {

        return Promise { seal in
            let dummyPrice: Subscribable<Double> = Subscribable<Double>(nil)
            let configuration: TransactionConfirmationConfiguration = .dappTransaction(confirmType: type, keystore: keystore, ethPrice: dummyPrice)

            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, account: account, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator).map { data -> WalletConnectServer.Callback in
                switch data {
                case .signedTransaction(let data):
                    return .init(id: id, url: url, value: .signTransaction(data))
                case .sentTransaction(let transaction):
                    let data = Data(hex: transaction.id)
                    return .init(id: id, url: url, value: .sentTransaction(data))
                case .sentRawTransaction:
                    //NOTE: Doesn't support sentRawTransaction for TransactionConfirmationCoordinator, for it we are using another function
                    throw PMKError.cancelled
                }
            }.done { callback in
                //NOTE: Show transaction in progress only for sent transactions
                switch type {
                case .sign:
                    break
                case .signThenSend:
                    TransactionInProgressCoordinator.promise(navigationController: self.navigationController, coordinator: self).done { _ in
                        //no op
                    }.cauterize()
                }

                seal.fulfill(callback)
            }.catch { error in
                if case DAppError.cancelled = error {
                    //no op
                } else {
                    self.navigationController.displayError(error: error)
                }

                seal.reject(error)
            }
        }
    }

    func server(_ server: WalletConnectServer, didFail error: Error) {
        navigationController.displaySuccess(message: R.string.localizable.walletConnectFailureTitle())
    }

    func server(_ server: WalletConnectServer, shouldConnectFor connection: WalletConnectConnection, completion: @escaping (Bool) -> Void) {
        showConnectToSession(title: connection.name, url: connection.url, completion: completion)
    }

    //TODO after we support sendRawTransaction in dapps (and hence a proper UI, be it the actionsheet for transaction confirmation or a simple prompt), let's modify this to use the same flow
    private func send(rawTransaction: String, callbackID id: WalletConnectRequestID, url: WalletConnectURL) -> Promise<WalletConnectServer.Callback> {
        return firstly {
            showSignRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: rawTransaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: DAppError.cancelled) }

            let coordinator = SendTransactionCoordinator(session: self.session, keystore: self.keystore, confirmType: .sign)
            return coordinator.send(rawTransaction: rawTransaction)
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw PMKError.cancelled
            case .sentRawTransaction(let transactionId, _):
                let data = Data(hex: transactionId)
                return .init(id: id, url: url, value: .sentTransaction(data))
            }
        }.then { callback -> Promise<WalletConnectServer.Callback> in
            return self.showFeedbackOnSuccess(callback)
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

    private func showFeedbackOnSuccess<T>(_ value: T) -> Promise<T> {
        return Promise { seal in
            UINotificationFeedbackGenerator.show(feedbackType: .success) {
                seal.fulfill(value)
            }
        }
    }

    private func showConnectToSession(title: String, url: String, completion: @escaping (Bool) -> Void) {
        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let alertViewController = UIAlertController(title: title, message: url, preferredStyle: style)
        let startAction = UIAlertAction(title: R.string.localizable.start(), style: .default) { _ in
            completion(true)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            completion(false)
        }

        alertViewController.addAction(startAction)
        alertViewController.addAction(cancelAction)

        navigationController.present(alertViewController, animated: true)
    }
}

extension String {

    var toHexData: Data {
        if self.hasPrefix("0x") {
            return Data(hex: self)
        } else {
            return Data(hex: self.hex)
        }
    }
}
