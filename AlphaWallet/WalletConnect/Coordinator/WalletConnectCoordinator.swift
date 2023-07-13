//
//  WalletConnectCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import AlphaWalletGoBack
import WalletConnectSwift
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletCore

protocol WalletConnectCoordinatorDelegate: DappRequesterDelegate {
    func universalScannerSelected(in coordinator: WalletConnectCoordinator)
}

class WalletConnectCoordinator: NSObject, Coordinator {
    private let navigationController: UINavigationController
    private let analytics: AnalyticsLogger
    private weak var connectionTimeoutViewController: WalletConnectConnectionTimeoutViewController?
    private weak var notificationAlertController: UIViewController?
    private weak var sessionsViewController: WalletConnectSessionsViewController?
    private let restartHandler: RestartQueueHandler
    private let serversProvider: ServersProvidable

    let walletConnectProvider: WalletConnectProvider

    weak var delegate: WalletConnectCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(navigationController: UINavigationController, analytics: AnalyticsLogger, walletConnectProvider: WalletConnectProvider, restartHandler: RestartQueueHandler, serversProvider: ServersProvidable) {
        self.serversProvider = serversProvider
        self.restartHandler = restartHandler
        self.walletConnectProvider = walletConnectProvider
        self.navigationController = navigationController
        self.analytics = analytics

        super.init()
        walletConnectProvider.delegate = self
    }

    func openSession(url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if sessionsViewController == nil {
            navigationController.setNavigationBarHidden(false, animated: true)
        }

        showSessions(state: .waitingForSessionConnection, navigationController: navigationController) {
            do {
                try self.walletConnectProvider.connect(url: url)
            } catch {
                let errorMessage = R.string.localizable.walletConnectFailureTitle()
                self.displayErrorMessage(errorMessage)
            }
        }
    }

    func showSessionDetails(in navigationController: UINavigationController) {
        if walletConnectProvider.sessions.count == 1 {
            display(session: walletConnectProvider.sessions[0], in: navigationController)
        } else {
            showSessions(state: .sessions, navigationController: navigationController)
        }
    }

    func showSessions() {
        navigationController.setNavigationBarHidden(false, animated: false)
        showSessions(state: .sessions, navigationController: navigationController)

        if walletConnectProvider.sessions.isEmpty {
            startUniversalScanner()
        }
    }

    private func showSessions(state: WalletConnectSessionsViewModel.State, navigationController: UINavigationController, completion: @escaping () -> Void = {}) {
        if let viewController = sessionsViewController {
            viewController.viewModel.set(state: state)
            completion()
        } else {
            let viewController = WalletConnectSessionsViewController(viewModel: .init(walletConnectProvider: walletConnectProvider, state: state))
            viewController.delegate = self
            viewController.navigationItem.rightBarButtonItem = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(qrCodeButtonSelected))
            viewController.navigationItem.largeTitleDisplayMode = .never
            viewController.hidesBottomBarWhenPushed = true

            sessionsViewController = viewController

            navigationController.pushViewController(viewController, animated: true, completion: completion)
        }
    }

    @objc private func qrCodeButtonSelected(_ sender: UIBarButtonItem) {
        startUniversalScanner()
    }

    private func display(session: AlphaWallet.WalletConnect.Session, in navigationController: UINavigationController) {
        let coordinator = WalletConnectSessionCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            walletConnectProvider: walletConnectProvider,
            session: session,
            serversProvider: serversProvider)

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

extension WalletConnectCoordinator: WalletConnectProviderDelegate {

    func requestEthCall(from: AlphaWallet.Address?,
                        to: AlphaWallet.Address?,
                        value: String?,
                        data: String,
                        source: Analytics.SignMessageRequestSource,
                        session: WalletSession) -> AnyPublisher<String, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestEthCall(
            from: from,
            to: to,
            value: value,
            data: data,
            source: source,
            session: session)
    }

    func requestGetTransactionCount(session: WalletSession,
                                    source: Analytics.SignMessageRequestSource) -> AnyPublisher<Data, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestGetTransactionCount(
            session: session,
            source: source)
    }

    func requestSignMessage(message: SignMessageType,
                            server: RPCServer,
                            account: AlphaWallet.Address,
                            source: Analytics.SignMessageRequestSource,
                            requester: RequesterViewModel?) -> AnyPublisher<Data, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestSignMessage(
            message: message,
            server: server,
            account: account,
            source: source,
            requester: requester)
    }

    func requestSendRawTransaction(session: WalletSession,
                                   source: Analytics.TransactionConfirmationSource,
                                   requester: DappRequesterViewModel?,
                                   transaction: String) -> AnyPublisher<String, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestSendRawTransaction(
            session: session,
            source: source,
            requester: requester,
            transaction: transaction)
    }

    func requestSendTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<SentTransaction, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestSendTransaction(
            session: session,
            source: source,
            requester: requester,
            transaction: transaction,
            configuration: configuration)
    }

    func requestSignTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<Data, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestSignTransaction(
            session: session,
            source: source,
            requester: requester,
            transaction: transaction,
            configuration: configuration)
    }

    func requestAddCustomChain(server: RPCServer,
                               customChain: WalletAddEthereumChainObject) -> AnyPublisher<SwitchCustomChainOperation, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestAddCustomChain(server: server, customChain: customChain)
    }

    func requestSwitchChain(server: RPCServer,
                            currentUrl: URL?,
                            targetChain: WalletSwitchEthereumChainObject) -> AnyPublisher<SwitchExistingChainOperation, PromiseError> {

        guard let delegate = delegate else { return .empty() }

        return delegate.requestSwitchChain(server: server, currentUrl: nil, targetChain: targetChain)
    }

    private func resetSessionsToRemoveLoadingIfNeeded() {
        if let viewController = sessionsViewController {
            viewController.viewModel.set(state: .sessions)
        }
    }

    func provider(_ provider: WalletConnectProvider, didConnect walletConnectSession: AlphaWallet.WalletConnect.Session) {
        infoLog("[WalletConnect] didConnect session: \(walletConnectSession.topicOrUrl)")
        resetSessionsToRemoveLoadingIfNeeded()
    }

    private var presentationViewController: UIViewController {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return navigationController }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            return controller
        } else {
            return navigationController
        }
    }

    func provider(_ provider: WalletConnectProvider, didFail error: WalletConnectError) {
        infoLog("[WalletConnect] didFail error: \(error)")

        guard let description = error.errorDescription else { return }
        displayErrorMessage(description)
    }

    func provider(_ provider: WalletConnectProvider, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {
        if Features.current.isAvailable(.isUsingAppEnforcedTimeoutForMakingWalletConnectConnections) {
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

    func provider(_ provider: WalletConnectProvider,
                  shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal) -> AnyPublisher<AlphaWallet.WalletConnect.ProposalResponse, Never> {

        infoLog("[WalletConnect] shouldConnectFor connection: \(proposal)")
        let proposalType: ProposalType = .walletConnect(.init(proposal: proposal, serversProvider: serversProvider))

        return AcceptProposalCoordinator.promise(navigationController, coordinator: self, proposalType: proposalType, analytics: analytics, restartHandler: restartHandler)
        .publisher()
        .map { choise -> AlphaWallet.WalletConnect.ProposalResponse in
            guard case .walletConnect(let server) = choise else { return .cancel }
            return .connect(server)
        }.replaceError(with: .cancel)
            .handleEvents(receiveOutput: { response in
                switch response {
                case .cancel:
                    JumpBackToPreviousApp.goBackForWalletConnectSessionCancelled()
                case .connect:
                    JumpBackToPreviousApp.goBackForWalletConnectSessionApproved()
                }
            }).handleEvents(receiveCompletion: { _ in self.resetSessionsToRemoveLoadingIfNeeded() })
            .eraseToAnyPublisher()
    }

    func provider(_ provider: WalletConnectProvider, shouldAccept authRequest: AlphaWallet.WalletConnect.AuthRequest) -> AnyPublisher<AlphaWallet.WalletConnect.AuthRequestResponse, Never> {
        infoLog("[WalletConnect] shouldAccept authRequest: \(authRequest)")
        return AcceptAuthRequestCoordinator.promise(navigationController, coordinator: self, authRequest: authRequest, analytics: analytics)
            .publisher()
            .map { choice -> AlphaWallet.WalletConnect.AuthRequestResponse in
                switch choice {
                case .accept(let server):
                    return .connect(server)
                case .cancel:
                    return .cancel
                }
            }
            .replaceError(with: .cancel)
            .handleEvents(receiveOutput: { response in
                switch response {
                case .cancel:
                    JumpBackToPreviousApp.goBackForWalletConnectSessionCancelled()
                case .connect:
                    JumpBackToPreviousApp.goBackForWalletConnectSessionApproved()
                }
            }).handleEvents(receiveCompletion: { _ in self.resetSessionsToRemoveLoadingIfNeeded() })
            .eraseToAnyPublisher()
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
    }

    func didDisconnectSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController) {
        infoLog("[WalletConnect] didDisconnect session: \(session.topicOrUrl.description)")
        analytics.log(action: Analytics.Action.walletConnectDisconnect)
        do {
            try walletConnectProvider.disconnect(session.topicOrUrl)
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
