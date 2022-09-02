//
//  WalletConnectCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import AlphaWalletGoBack
import WalletConnectSwift
import PromiseKit
import Combine
import AlphaWalletFoundation

protocol RequestAddCustomChainProvider: NSObjectProtocol {
    func requestAddCustomChain(server: RPCServer, callbackId: SwitchCustomChainCallbackId, customChain: WalletAddEthereumChainObject)
}
protocol RequestSwitchChainProvider: NSObjectProtocol {
    func requestSwitchChain(server: RPCServer, currentUrl: URL?, callbackID: SwitchCustomChainCallbackId, targetChain: WalletSwitchEthereumChainObject)
}

protocol WalletConnectCoordinatorDelegate: CanOpenURL, SendTransactionAndFiatOnRampDelegate, RequestAddCustomChainProvider, RequestSwitchChainProvider {
    func universalScannerSelected(in coordinator: WalletConnectCoordinator)
}

class WalletConnectCoordinator: NSObject, Coordinator {

    private lazy var walletConnectV2service: WalletConnectV2Provider = {
        let walletConnectV2service = WalletConnectV2Provider(serviceProvider: sessionProvider)
        walletConnectV2service.delegate = self

        return walletConnectV2service
    }()

    private lazy var walletConnectV1service: WalletConnectV1Provider = {
        let walletConnectV1service = WalletConnectV1Provider(serviceProvider: sessionProvider)
        walletConnectV1service.delegate = self

        return walletConnectV1service
    }()

    private lazy var provider: WalletConnectServerProviderType = {
        let provider = WalletConnectServerProvider()
        provider.register(service: walletConnectV1service)
        provider.register(service: walletConnectV2service)

        return provider
    }()

    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let config: Config
    private weak var connectionTimeoutViewController: WalletConnectConnectionTimeoutViewController?
    private weak var notificationAlertController: UIViewController?
    private weak var sessionsViewController: WalletConnectSessionsViewController?
    private let sessionProvider: SessionsProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private var tokensService: TokenViewModelState?
    weak var delegate: WalletConnectCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> {
        provider.sessions
    }

    init(keystore: Keystore, navigationController: UINavigationController, analytics: AnalyticsLogger, domainResolutionService: DomainResolutionServiceType, config: Config, sessionProvider: SessionsProvider, assetDefinitionStore: AssetDefinitionStore) {
        self.sessionProvider = sessionProvider
        self.config = config
        self.keystore = keystore
        self.navigationController = navigationController
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.assetDefinitionStore = assetDefinitionStore
        super.init()
        start()
    }
    //FIXME: think about better way
    func configure(with tokensService: TokenViewModelState?) {
        self.tokensService = tokensService
    }

    //NOTE: we are using disconnection to notify dapp that we get disconnect, in other case dapp still stay connected
    func disconnect(sessionsToDisconnect: SessionsToDisconnect) {
        var cancellable: AnyCancellable?
        cancellable = provider.sessions
            .receive(on: RunLoop.main)
            .sink { sessions in
                cancellable?.cancel()

                let filteredSessions: [NFDSession]
                switch sessionsToDisconnect {
                case .all:
                    filteredSessions = sessions.map { session in
                        return (session, session.servers)
                    }
                case .allExcept(let servers):
                    filteredSessions = sessions.compactMap { session -> NFDSession? in
                        let serversToDisconnect = session.servers.filter { !servers.contains($0) }
                        if serversToDisconnect.isEmpty {
                            return nil
                        } else {
                            return (session, serversToDisconnect)
                        }
                    }
                }
                do {
                    try self.provider.disconnectSession(sessions: filteredSessions)
                } catch {
                    let errorMessage = R.string.localizable.walletConnectFailureTitle()
                    self.displayErrorMessage(errorMessage)
                }
            }
    }

    private func start() {
        var cancellable: AnyCancellable?
        cancellable = provider.sessions
            .receive(on: RunLoop.main)
            .sink { sessions in
                cancellable?.cancel()
                for each in sessions {
                    do {
                        try self.provider.reconnect(each.topicOrUrl)
                    } catch {
                        let errorMessage = R.string.localizable.walletConnectFailureTitle()
                        self.displayErrorMessage(errorMessage)
                    }
                }
            }
    }

    func openSession(url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if sessionsViewController == nil {
            navigationController.setNavigationBarHidden(false, animated: true)
        }

        showSessions(state: .waitingForSessionConnection, navigationController: navigationController) {
            do {
                try self.provider.connect(url: url)
            } catch {
                let errorMessage = R.string.localizable.walletConnectFailureTitle()
                self.displayErrorMessage(errorMessage)
            }
        }
    }

    func showSessionDetails(in navigationController: UINavigationController) {
        var cancellable: AnyCancellable?
        cancellable = provider.sessions
            .receive(on: RunLoop.main)
            .sink { sessions in
                if sessions.count == 1 {
                    self.display(session: sessions[0], in: navigationController)
                } else {
                    self.showSessions(state: .sessions, navigationController: navigationController)
                }
                cancellable?.cancel()
            }
    }

    func showSessions() {
        var cancellable: AnyCancellable?
        cancellable = provider.sessions
            .receive(on: RunLoop.main)
            .sink { sessions in
                cancellable?.cancel()

                self.navigationController.setNavigationBarHidden(false, animated: false)
                self.showSessions(state: .sessions, navigationController: self.navigationController)

                if sessions.isEmpty {
                    self.startUniversalScanner()
                }
            }
    }

    private func showSessions(state: WalletConnectSessionsViewModel.State, navigationController: UINavigationController, completion: @escaping () -> Void = {}) {
        if let viewController = sessionsViewController {
            viewController.viewModel.set(state: state)
            completion()
        } else {
            let viewController = WalletConnectSessionsViewController(viewModel: .init(provider: provider, state: state))
            viewController.delegate = self

            sessionsViewController = viewController

            navigationController.pushViewController(viewController, animated: true, completion: completion)
        }
    }

    private func display(session: AlphaWallet.WalletConnect.Session, in navigationController: UINavigationController) {
        let coordinator = WalletConnectSessionCoordinator(analytics: analytics, navigationController: navigationController, provider: provider, session: session)
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
    func didClose(in coordinator: WalletConnectSessionCoordinator) {
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
                return .init(error: RequestCanceledDueToWatchWalletError())
            }
        }
    }
}

extension WalletConnectCoordinator: WalletConnectServerDelegate {
    private func resetSessionsToRemoveLoadingIfNeeded() {
        if let viewController = sessionsViewController {
            viewController.viewModel.set(state: .sessions)
        }
    }

    func server(_ server: WalletConnectServer, didConnect walletConnectSession: AlphaWallet.WalletConnect.Session) {
        infoLog("[WalletConnect] didConnect session: \(walletConnectSession.topicOrUrl)")
        resetSessionsToRemoveLoadingIfNeeded()
    }

    func server(_ server: WalletConnectServer, action: AlphaWallet.WalletConnect.Action, request: AlphaWallet.WalletConnect.Session.Request, session walletConnectSession: AlphaWallet.WalletConnect.Session) {
        infoLog("[WalletConnect] action: \(action)")

        guard let walletSession = request.server.flatMap({ sessionProvider.session(for: $0) }) else {
            try? server.respond(.init(error: .requestRejected), request: request)
            return
        }

        let requester = DappRequesterViewModel(requester: Requester(walletConnectSession: walletConnectSession, request: request))
        let account = walletSession.account.address

        firstly {
            walletSession.account.type.promisify
        }.then { _ -> Promise<AlphaWallet.WalletConnect.Response> in
            switch action.type {
            case .signTransaction(let transaction):
                return self.executeTransaction(session: walletSession, requester: requester, transaction: transaction, type: .sign)
            case .sendTransaction(let transaction):
                return self.executeTransaction(session: walletSession, requester: requester, transaction: transaction, type: .signThenSend)
            case .signMessage(let hexMessage):
                return self.signMessage(with: .message(hexMessage.toHexData), account: account, requester: requester)
            case .signPersonalMessage(let hexMessage):
                return self.signMessage(with: .personalMessage(hexMessage.toHexData), account: account, requester: requester)
            case .signTypedMessageV3(let typedData):
                return self.signMessage(with: .eip712v3And4(typedData), account: account, requester: requester)
            case .typedMessage(let typedData):
                return self.signMessage(with: .typedMessage(typedData), account: account, requester: requester)
            case .sendRawTransaction(let raw):
                return self.sendRawTransaction(session: walletSession, rawTransaction: raw)
            case .getTransactionCount:
                return self.getTransactionCount(session: walletSession)
            case .unknown:
                throw PMKError.cancelled
            case .walletAddEthereumChain(let object):
                return self.addCustomChain(object: object, request: request, walletConnectSession: walletConnectSession)
            case .walletSwitchEthereumChain(let object):
                return self.switchChain(object: object, request: request, walletConnectSession: walletConnectSession)
            }
        }.done { response in
            try? server.respond(response, request: request)
        }.ensure {
            JumpBackToPreviousApp.goBack(forWalletConnectAction: action)
        }.catch { error in
            if error is RequestCanceledDueToWatchWalletError {
                self.navigationController.displayError(error: error)
            }

            if error is DelayWalletConnectResponseError {
                //no-op
            } else {
                try? server.respond(.init(error: .requestRejected), request: request)
            }
        }
    }

    func responseServerChangeSucceed(request: AlphaWallet.WalletConnect.Session.Request) throws {
        return try respond(response: .value(nil), request: request)
    }

    func respond(response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        try provider.respond(response, request: request)
    }

    //NOTE: even when we received `wallet_switchEthereumChain` and returned to served null as successfull response it doesn't cause server change in the dapp
    //we have to send swith server request manually
    //WARNING: tweak for WalletConnect v2 as it might accept several servers at once
    func notifyUpdateServers(request: AlphaWallet.WalletConnect.Session.Request, server: RPCServer) throws {
        try provider.update(request.topicOrUrl, servers: [server])
    }

    private func switchChain(object targetChain: WalletSwitchEthereumChainObject, request: AlphaWallet.WalletConnect.Session.Request, walletConnectSession: AlphaWallet.WalletConnect.Session) -> Promise<AlphaWallet.WalletConnect.Response> {
        infoLog("[WalletConnect] switchChain: \(targetChain)")
        //NOTE: DappRequestSwitchExistingChainCoordinator requires current selected server, (from dapp impl) if we pass server that isn't currently selected it will ask to switch server 2 times, for this we return server that is already selected
        func firstEnabledRPCServer() -> RPCServer? {
            let server = targetChain.server.flatMap { server in sessionProvider.session(for: server)?.server }

            return server ?? walletConnectSession.servers.first
        }

        guard let server = firstEnabledRPCServer(), targetChain.server != nil else {
            return .value(.init(error: .unsupportedChain(chainId: targetChain.chainId)))
        }

        let callbackID: SwitchCustomChainCallbackId = .walletConnect(request: request)
        delegate?.requestSwitchChain(server: server, currentUrl: nil, callbackID: callbackID, targetChain: targetChain)

        return .init(error: DelayWalletConnectResponseError())
    }

    private func addCustomChain(object customChain: WalletAddEthereumChainObject, request: AlphaWallet.WalletConnect.Session.Request, walletConnectSession: AlphaWallet.WalletConnect.Session) -> Promise<AlphaWallet.WalletConnect.Response> {
        infoLog("[WalletConnect] addCustomChain: \(customChain)")
        guard let server = walletConnectSession.servers.first else {
            return .value(.init(error: .requestRejected))
        }

        let callbackId: SwitchCustomChainCallbackId = .walletConnect(request: request)
        delegate?.requestAddCustomChain(server: server, callbackId: callbackId, customChain: customChain)

        return .init(error: DelayWalletConnectResponseError())
    }

    private func signMessage(with type: SignMessageType, account: AlphaWallet.Address, requester: RequesterViewModel) -> Promise<AlphaWallet.WalletConnect.Response> {
        infoLog("[WalletConnect] signMessage: \(type)")

        return firstly {
            SignMessageCoordinator.promise(analytics: analytics, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .walletConnect, requester: requester)
        }.map { data -> AlphaWallet.WalletConnect.Response in
            return .value(data)
        }
    }

    private func executeTransaction(session: WalletSession, requester: DappRequesterViewModel, transaction: UnconfirmedTransaction, type: ConfirmType) -> Promise<AlphaWallet.WalletConnect.Response> {

        let configuration: TransactionType.Configuration = .walletConnect(confirmType: type, requester: requester)
        guard let tokensService = tokensService else { return Promise<AlphaWallet.WalletConnect.Response> { _ in } }

        infoLog("[WalletConnect] executeTransaction: \(transaction) type: \(type)")
        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, source: .walletConnect, delegate: self.delegate, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokensService)
        }.map { data -> AlphaWallet.WalletConnect.Response in
            switch data {
            case .signedTransaction(let data):
                return .value(data)
            case .sentTransaction(let transaction):
                return .value(Data(_hex: transaction.id))
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
        }.recover { error -> Promise<AlphaWallet.WalletConnect.Response> in
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

    func server(_ server: WalletConnectServer, didFail error: Error) {
        infoLog("[WalletConnect] didFail error: \(error)")
        let errorMessage = R.string.localizable.walletConnectFailureTitle()
        displayErrorMessage(errorMessage)
    }

    func server(_ server: WalletConnectServer, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if Features.default.isAvailable(.isUsingAppEnforcedTimeoutForMakingWalletConnectConnections) {
            infoLog("[WalletConnect] app-enforced timeout for waiting for new connection")
            analytics.log(action: Analytics.Action.walletConnectConnectionTimeout, properties: [
                Analytics.WalletConnectAction.connectionUrl.rawValue: url.absoluteString
            ])
            let errorMessage = R.string.localizable.walletConnectErrorConnectionTimeoutErrorMessage()
            displayConnectionTimeout(errorMessage)
        } else {
            infoLog("[WalletConnect] app-enforced timeout for waiting for new connection. Disabled")
        }
    }

    func server(_ server: WalletConnectServer, shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal, completion: @escaping (AlphaWallet.WalletConnect.ProposalResponse) -> Void) {
        infoLog("[WalletConnect] shouldConnectFor connection: \(proposal)")
        let proposalType: ProposalType = .walletConnect(.init(proposal: proposal, config: config))
        firstly {
            AcceptProposalCoordinator.promise(navigationController, coordinator: self, proposalType: proposalType, analytics: analytics)
        }.done { choise in
            guard case .walletConnect(let server) = choise else {
                completion(.cancel)
                JumpBackToPreviousApp.goBackForWalletConnectSessionCancelled()
                return
            }
            completion(.connect(server))
            JumpBackToPreviousApp.goBackForWalletConnectSessionApproved()
        }.catch { _ in
            completion(.cancel)
        }.finally {
            self.resetSessionsToRemoveLoadingIfNeeded()
        }
    }

    private func sendRawTransaction(session: WalletSession, rawTransaction: String) -> Promise<AlphaWallet.WalletConnect.Response> {
        infoLog("[WalletConnect] sendRawTransaction: \(rawTransaction)")
        return firstly {
            showSignRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: rawTransaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: DAppError.cancelled) }
            let prompt = R.string.localizable.keystoreAccessKeySign()
            let sender = SendTransaction(session: session, keystore: self.keystore, confirmType: .sign, config: self.config, analytics: self.analytics, prompt: prompt)
            return sender.send(rawTransaction: rawTransaction)
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw PMKError.cancelled
            case .sentRawTransaction(let transactionId, _):
                return .value(Data(_hex: transactionId))
            }
        }.then { callback -> Promise<AlphaWallet.WalletConnect.Response> in
            return UINotificationFeedbackGenerator.showFeedbackPromise(value: callback, feedbackType: .success)
        }
    }

    private func getTransactionCount(session: WalletSession) -> Promise<AlphaWallet.WalletConnect.Response> {
        return firstly {
            GetNextNonce(server: session.server, wallet: session.account.address, analytics: analytics).promise()
        }.map {
            if let data = Data(fromHexEncodedString: String(format: "%02X", $0)) {
                return .value(data)
            } else {
                throw PMKError.badInput
            }
        }
    }

    private func showSignRawTransaction(title: String, message: String) -> Promise<Bool> {
        infoLog("[WalletConnect] showSignRawTransaction title: \(title) message: \(message)")
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
        infoLog("[WalletConnect] didClose")
        //NOTE: even if we haven't sessions view controller pushed to navigation stack, we need to make sure that root NavigationBar will be hidden
        navigationController.setNavigationBarHidden(true, animated: false)

        guard let navigationController = viewController.navigationController else { return }
        navigationController.popViewController(animated: true)
    }

    func didDisconnectSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController) {
        infoLog("[WalletConnect] didDisconnect session: \(session.topicOrUrl.description)")
        analytics.log(action: Analytics.Action.walletConnectDisconnect)
        do {
            try provider.disconnect(session.topicOrUrl)
        } catch {
            let errorMessage = R.string.localizable.walletConnectFailureTitle()
            displayErrorMessage(errorMessage)
        }
    }

    func didSessionSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController) {
        infoLog("[WalletConnect] didSelect session: \(session)")
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

fileprivate class JumpBackToPreviousApp {
    static func goBack(forWalletConnectAction action: AlphaWallet.WalletConnect.Action) {
        if action.type.shouldGoBackToPreviousAppAfterAction {
            _ = UIApplication.shared.goBackToPreviousAppIfAvailable()
        } else {
            //no-op
        }
    }

    static func goBackForWalletConnectSessionApproved() {
        _ = UIApplication.shared.goBackToPreviousAppIfAvailable()
    }

    static func goBackForWalletConnectSessionCancelled() {
        _ = UIApplication.shared.goBackToPreviousAppIfAvailable()
    }
}

fileprivate extension AlphaWallet.WalletConnect.Action.ActionType {
    var shouldGoBackToPreviousAppAfterAction: Bool {
        switch self {
        case .signMessage, .signPersonalMessage, .signTypedMessageV3, .signTransaction, .sendTransaction, .typedMessage, .sendRawTransaction, .walletSwitchEthereumChain, .walletAddEthereumChain:
            return true
        case .getTransactionCount, .unknown:
            return false
        }
    }
}
