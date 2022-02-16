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

protocol WalletConnectCoordinatorDelegate: CanOpenURL, SendTransactionAndFiatOnRampDelegate {
    func universalScannerSelected(in coordinator: WalletConnectCoordinator)
}

class WalletConnectCoordinator: NSObject, Coordinator {
    private lazy var provider: WalletConnectServerProviderType = {
        let provider = WalletConnectServerProvider()
        let walletConnectV1service = WalletConnectV1Provider(wallet: sessions.anyValue.account.address)
        walletConnectV1service.delegate = self

        let walletConnectV2service = WalletConnectV2Provider(sessions: sessions)
        walletConnectV2service.delegate = self

        provider.register(service: walletConnectV1service)
        provider.register(service: walletConnectV2service)

        return provider
    }()

    private let navigationController: UINavigationController

    var coordinators: [Coordinator] = []
    var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> {
        provider.sessionsSubscribable
    }

    private let keystore: Keystore
    private let sessions: ServerDictionary<WalletSession>
    private let analyticsCoordinator: AnalyticsCoordinator
    private let config: Config
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>
    private weak var connectionTimeoutViewController: WalletConnectConnectionTimeoutViewController?
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
    }

    //NOTE: we are using disconnection to notify dapp that we get disconnect, in other case dapp still stay connected
    func disconnect(sessionsToDisconnect: SessionsToDisconnect) {
        let filteredSessions: [NFDSession]
        switch sessionsToDisconnect {
        case .all:
            filteredSessions = provider.sessions.map { session in
                return (session, session.servers)
            }
        case .allExcept(let servers):
            filteredSessions = provider.sessions.compactMap { session -> NFDSession? in
                let serversToDisconnect = session.servers.filter { !servers.contains($0) }
                if serversToDisconnect.isEmpty {
                    return nil
                } else {
                    return (session, serversToDisconnect)
                }
            }
        }
        do {
            try provider.disconnectSession(sessions: filteredSessions)
        } catch {
            let errorMessage = R.string.localizable.walletConnectFailureTitle()
            displayErrorMessage(errorMessage)
        }
    }

    private func start() {
        for each in provider.sessions {
            do {
                try provider.reconnectSession(session: each)
            } catch {
                let errorMessage = R.string.localizable.walletConnectFailureTitle()
                displayErrorMessage(errorMessage)
            }
        }
    }

    func openSession(url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if sessionsViewController == nil {
            navigationController.setNavigationBarHidden(false, animated: true)
        }

        showSessions(state: .loading, navigationController: navigationController) {
            do {
                try self.provider.connect(url: url)
            } catch {
                let errorMessage = R.string.localizable.walletConnectFailureTitle()
                self.displayErrorMessage(errorMessage)
            }
        }
    }

    func showSessionDetails(in navigationController: UINavigationController) {
        if provider.sessions.count == 1 {
            display(session: provider.sessions[0], in: navigationController)
        } else {
            showSessions(state: .sessions, navigationController: navigationController)
        }
    }

    func showSessions() {
        navigationController.setNavigationBarHidden(false, animated: false)
        showSessions(state: .sessions, navigationController: navigationController)

        if provider.sessions.isEmpty {
            startUniversalScanner()
        }
    }

    private func showSessions(state: WalletConnectSessionsViewController.State, navigationController: UINavigationController, completion: @escaping () -> Void = {}) {
        if let viewController = sessionsViewController {
            viewController.configure(state: state)
            completion()
        } else {
            let viewController = WalletConnectSessionsViewController(sessionsSubscribable: sessionsSubscribable)
            viewController.delegate = self
            viewController.configure(state: state)

            sessionsViewController = viewController

            navigationController.pushViewController(viewController, animated: true, completion: completion)
        }
    }

    private func display(session: AlphaWallet.WalletConnect.Session, in navigationController: UINavigationController) {
        let coordinator = WalletConnectSessionCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, provider: provider, session: session)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func displayConnectionTimeout(_ errorMessage: String) {
        func displayConnectionTimeoutViewPopup(message: String) {
            let pair = WalletConnectConnectionTimeoutViewController.promise(presentationViewController, errorMessage: errorMessage)
            notificationAlertController = pair.viewController

            pair.promise.done({ response in
                switch response {
                case .action:
                    self.delegate?.universalScannerSelected(in: self)
                case .canceled:
                    break
                }
            }).cauterize()
        }

        if let viewController = connectionTimeoutViewController {
            viewController.dismissAnimated(completion: {
                displayConnectionTimeoutViewPopup(message: errorMessage)
            })
        } else {
            displayConnectionTimeoutViewPopup(message: errorMessage)
        }

        resetSessionsToRemoveLoadingIfNeeded()
    }

    private func displayErrorMessage(_ errorMessage: String) {
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
}

extension WalletConnectCoordinator: WalletConnectSessionCoordinatorDelegate {
    func didDismiss(in coordinator: WalletConnectSessionCoordinator) {
        removeCoordinator(coordinator)
    }
}

private extension WalletType {
    var promisify: Promise<Void> {
        switch self {
        case .real:
            return .value(())
        case .watch:
            //TODO pass in Config instance instead
            if Config().development.shouldPretendIsRealWallet {
                return .value(())
            } else {
                return .init(error: WalletConnectCoordinator.RequestCanceledDueToWatchWalletError())
            }
        }
    }
}

extension WalletConnectCoordinator: WalletConnectServerDelegate {
    struct RequestCanceledDueToWatchWalletError: Error {
        var localizedDescription: String {
            return R.string.localizable.walletConnectFailureMustNotBeWatchedWallet()
        }
    }

    private func resetSessionsToRemoveLoadingIfNeeded() {
        if let viewController = sessionsViewController {
            viewController.set(state: .sessions)
        }
    }

    func server(_ server: WalletConnectServerType, didConnect walletConnectSession: AlphaWallet.WalletConnect.Session) {
        infoLog("WalletConnect didConnect session: \(walletConnectSession.identifier)")
        resetSessionsToRemoveLoadingIfNeeded()
    }

    func server(_ server: WalletConnectServerType, action: AlphaWallet.WalletConnect.Action, request: AlphaWallet.WalletConnect.Session.Request, session walletConnectSession: AlphaWallet.WalletConnect.Session) {
        infoLog("WalletConnect action: \(action)")
        guard let walletSession = request.server.flatMap({ sessions[$0] }) else { return }

        let dappRequesterViewModel = WalletConnectDappRequesterViewModel(walletConnectSession: walletConnectSession, request: request)

        firstly {
            walletSession.account.type.promisify
        }.then { _ -> Promise<AlphaWallet.WalletConnect.Callback> in
            let account = walletSession.account.address
            switch action.type {
            case .signTransaction(let transaction):
                return self.executeTransaction(session: walletSession, dappRequesterViewModel: dappRequesterViewModel, transaction: transaction, type: .sign)
            case .sendTransaction(let transaction):
                return self.executeTransaction(session: walletSession, dappRequesterViewModel: dappRequesterViewModel, transaction: transaction, type: .signThenSend)
            case .signMessage(let hexMessage):
                return self.signMessage(with: .message(hexMessage.toHexData), account: account, dappRequesterViewModel: dappRequesterViewModel)
            case .signPersonalMessage(let hexMessage):
                return self.signMessage(with: .personalMessage(hexMessage.toHexData), account: account, dappRequesterViewModel: dappRequesterViewModel)
            case .signTypedMessageV3(let typedData):
                return self.signMessage(with: .eip712v3And4(typedData), account: account, dappRequesterViewModel: dappRequesterViewModel)
            case .typedMessage(let typedData):
                return self.signMessage(with: .typedMessage(typedData), account: account, dappRequesterViewModel: dappRequesterViewModel)
            case .sendRawTransaction(let raw):
                return self.sendRawTransaction(session: walletSession, rawTransaction: raw)
            case .getTransactionCount:
                return self.getTransactionCount(session: walletSession)
            case .unknown:
                throw PMKError.cancelled
            }
        }.done { callback in
            try? server.fulfill(callback, request: request)
        }.catch { error in
            if error is WalletConnectCoordinator.RequestCanceledDueToWatchWalletError {
                self.navigationController.displayError(error: error)
            }
            server.reject(request)
        }
    }

    private func signMessage(with type: SignMessageType, account: AlphaWallet.Address, dappRequesterViewModel: WalletConnectDappRequesterViewModel) -> Promise<AlphaWallet.WalletConnect.Callback> {
        infoLog("WalletConnect signMessage: \(type)")

        return firstly {
            SignMessageCoordinator.promise(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .walletConnect, walletConnectDappRequesterViewModel: dappRequesterViewModel)
        }.map { data -> AlphaWallet.WalletConnect.Callback in
            return .init(value: data)
        }
    }

    private func executeTransaction(session: WalletSession, dappRequesterViewModel: WalletConnectDappRequesterViewModel, transaction: UnconfirmedTransaction, type: ConfirmType) -> Promise<AlphaWallet.WalletConnect.Callback> {

        let ethPrice = nativeCryptoCurrencyPrices[session.server]
        let configuration: TransactionConfirmationConfiguration = .walletConnect(confirmType: type, keystore: keystore, ethPrice: ethPrice, dappRequesterViewModel: dappRequesterViewModel)
        infoLog("WalletConnect executeTransaction: \(transaction) type: \(type)")
        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, source: .walletConnect, delegate: self.delegate)
        }.map { data -> AlphaWallet.WalletConnect.Callback in
            switch data {
            case .signedTransaction(let data):
                return .init(value: data)
            case .sentTransaction(let transaction):
                let data = Data(_hex: transaction.id)
                return .init(value: data)
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
        }.recover { error -> Promise<AlphaWallet.WalletConnect.Callback> in
            if case DAppError.cancelled = error {
                //no op
            } else {
                self.navigationController.displayError(error: error)
            }
            throw error
        }
    }

    private var presentationViewController: UIViewController {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return navigationController }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            return controller
        } else {
            return navigationController
        }
    }

    func server(_ server: WalletConnectServerType, didFail error: Error) {
        infoLog("WalletConnect didFail error: \(error)")
        let errorMessage = R.string.localizable.walletConnectFailureTitle()
        displayErrorMessage(errorMessage)
    }

    func server(_ server: WalletConnectServerType, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if Features.isUsingAppEnforcedTimeoutForMakingWalletConnectConnections {
            infoLog("WalletConnect app-enforced timeout for waiting for new connection")
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnectionTimeout, properties: [
                Analytics.WalletConnectAction.connectionUrl.rawValue: url.absoluteString
            ])
            let errorMessage = R.string.localizable.walletConnectErrorConnectionTimeoutErrorMessage()
            displayConnectionTimeout(errorMessage)
        } else {
            infoLog("WalletConnect app-enforced timeout for waiting for new connection. Disabled")
        }
    }

    func server(_ server: WalletConnectServerType, shouldConnectFor sessionProposal: AlphaWallet.WalletConnect.SessionProposal, completion: @escaping (AlphaWallet.WalletConnect.SessionProposalResponse) -> Void) {
        infoLog("WalletConnect shouldConnectFor connection: \(sessionProposal)")
        firstly {
            WalletConnectToSessionCoordinator.promise(navigationController, coordinator: self, sessionProposal: sessionProposal, serverChoices: serverChoices, analyticsCoordinator: analyticsCoordinator, config: config)
        }.done { choise in
            completion(choise)
        }.catch { _ in
            completion(.cancel)
        }.finally {
            self.resetSessionsToRemoveLoadingIfNeeded()
        }
    }

    private func sendRawTransaction(session: WalletSession, rawTransaction: String) -> Promise<AlphaWallet.WalletConnect.Callback> {
        infoLog("WalletConnect sendRawTransaction: \(rawTransaction)")
        return firstly {
            showSignRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: rawTransaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: DAppError.cancelled) }

            let coordinator = SendTransactionCoordinator(session: session, keystore: self.keystore, confirmType: .sign, config: self.config, analyticsCoordinator: self.analyticsCoordinator)
            return coordinator.send(rawTransaction: rawTransaction)
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw PMKError.cancelled
            case .sentRawTransaction(let transactionId, _):
                return .init(value: Data(_hex: transactionId))
            }
        }.then { callback -> Promise<AlphaWallet.WalletConnect.Callback> in
            return UINotificationFeedbackGenerator.showFeedbackPromise(value: callback, feedbackType: .success)
        }
    }

    private func getTransactionCount(session: WalletSession) -> Promise<AlphaWallet.WalletConnect.Callback> {
        return firstly {
            GetNextNonce(server: session.server, wallet: session.account.address).promise()
        }.map {
            if let data = Data(fromHexEncodedString: String(format: "%02X", $0)) {
                return .init(value: data)
            } else {
                throw PMKError.badInput
            }
        }
    }

    private func showSignRawTransaction(title: String, message: String) -> Promise<Bool> {
        infoLog("WalletConnect showSignRawTransaction title: \(title) message: \(message)")
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
    func startUniversalScanner() {
        delegate?.universalScannerSelected(in: self)
    }

    func qrCodeSelected(in viewController: WalletConnectSessionsViewController) {
        startUniversalScanner()
    }

    func didClose(in viewController: WalletConnectSessionsViewController) {
        infoLog("WalletConnect didClose")
        //NOTE: even if we haven't sessions view controller pushed to navigation stack, we need to make sure that root NavigationBar will be hidden
        navigationController.setNavigationBarHidden(true, animated: false)

        guard let navigationController = viewController.navigationController else { return }
        navigationController.popViewController(animated: true)
    }

    func didDisconnectSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController) {
        infoLog("WalletConnect didDisconnect session: \(session.identifier.description)")
        analyticsCoordinator.log(action: Analytics.Action.walletConnectDisconnect)
        do {
            try provider.disconnectSession(session: session)
        } catch {
            let errorMessage = R.string.localizable.walletConnectFailureTitle()
            displayErrorMessage(errorMessage)
        }
    }

    func didSessionSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController) {
        infoLog("WalletConnect didSelect session: \(session)")
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
