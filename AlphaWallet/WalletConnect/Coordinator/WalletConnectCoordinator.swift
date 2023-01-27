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
import AlphaWalletLogger
import AlphaWalletCore

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

    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let config: Config
    private weak var connectionTimeoutViewController: WalletConnectConnectionTimeoutViewController?
    private weak var notificationAlertController: UIViewController?
    private weak var sessionsViewController: WalletConnectSessionsViewController?
    private let assetDefinitionStore: AssetDefinitionStore
    private let networkService: NetworkService
    private let dependencies: AtomicDictionary<Wallet, AppCoordinator.WalletDependencies>

    let walletConnectProvider: WalletConnectProvider

    weak var delegate: WalletConnectCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(keystore: Keystore,
         navigationController: UINavigationController,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainResolutionServiceType,
         config: Config,
         assetDefinitionStore: AssetDefinitionStore,
         networkService: NetworkService,
         walletConnectProvider: WalletConnectProvider,
         dependencies: AtomicDictionary<Wallet, AppCoordinator.WalletDependencies>) {

        self.dependencies = dependencies
        self.walletConnectProvider = walletConnectProvider
        self.networkService = networkService
        self.config = config
        self.keystore = keystore
        self.navigationController = navigationController
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.assetDefinitionStore = assetDefinitionStore

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
            session: session)

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

    func requestGetTransactionCount(session: WalletSession) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        infoLog("[WalletConnect] getTransactionCount")
        return session.blockchainProvider
            .nextNonce(wallet: session.account.address)
            .mapError { PromiseError(error: $0) }
            .flatMap { nonce -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> in
                if let data = Data(fromHexEncodedString: String(format: "%02X", nonce)) {
                    return .just(.value(data))
                } else {
                    return .fail(PromiseError(error: PMKError.badInput))
                }
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func requestSignMessage(message: SignMessageType, account: AlphaWallet.Address, requester: RequesterViewModel) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        infoLog("[WalletConnect] signMessage: \(message)")
        return firstly {
            SignMessageCoordinator.promise(analytics: analytics, navigationController: navigationController, keystore: keystore, coordinator: self, signType: message, account: account, source: .walletConnect, requester: requester)
        }.map { data -> AlphaWallet.WalletConnect.Response in
            return .value(data)
        }.publisher(queue: .main)
    }

    func requestSendRawTransaction(session: WalletSession, requester: DappRequesterViewModel, transaction: String, configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        infoLog("[WalletConnect] signRawTransaction: \(transaction)")
        return firstly {
            showAskSendRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: transaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: DAppError.cancelled) }
            let prompt = R.string.localizable.keystoreAccessKeySign()
            let sender = SendTransaction(session: session, keystore: self.keystore, confirmType: .signThenSend, config: session.config, analytics: self.analytics, prompt: prompt)
            return sender.send(rawTransaction: transaction)
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw PMKError.cancelled
            case .sentRawTransaction(let transactionId, _):
                return .value(Data(_hex: transactionId))
            }
        }.then { callback -> Promise<AlphaWallet.WalletConnect.Response> in
            return UINotificationFeedbackGenerator.showFeedbackPromise(value: callback, feedbackType: .success)
        }.get { _ in
            TransactionInProgressCoordinator.promise(self.navigationController, coordinator: self).done { _ in }.cauterize()
        }.publisher(queue: .main)
    }

    func requestSendTransaction(session: WalletSession, requester: DappRequesterViewModel, transaction: UnconfirmedTransaction, configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        guard let dependency = dependencies[session.account] else { return .fail(PromiseError(error: PMKError.cancelled)) }

        infoLog("[WalletConnect] sendTransaction: \(transaction) type: \(configuration.confirmType)")

        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, source: .walletConnect, delegate: self.delegate, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: dependency.pipeline, networkService: networkService)
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
        }.get { _ in
            TransactionInProgressCoordinator.promise(self.navigationController, coordinator: self).done { _ in }.cauterize()
        }.publisher(queue: .main)
    }

    func requestSingTransaction(session: WalletSession, requester: DappRequesterViewModel, transaction: UnconfirmedTransaction, configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        guard let dependency = dependencies[session.account] else { return .fail(PromiseError(error: PMKError.cancelled)) }
        infoLog("[WalletConnect] singTransaction: \(transaction) type: \(configuration.confirmType)")

        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, source: .walletConnect, delegate: self.delegate, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: dependency.pipeline, networkService: networkService)
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
        }.publisher(queue: .main)
    }

    func requestAddCustomChain(server: RPCServer, callbackId: SwitchCustomChainCallbackId, customChain: WalletAddEthereumChainObject) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        infoLog("[WalletConnect] addCustomChain: \(customChain)")

        delegate?.requestAddCustomChain(server: server, callbackId: callbackId, customChain: customChain)

        return .fail(PromiseError(error: DelayWalletConnectResponseError()))
    }

    func requestSwitchChain(server: RPCServer, currentUrl: URL?, callbackID: SwitchCustomChainCallbackId, targetChain: WalletSwitchEthereumChainObject) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        infoLog("[WalletConnect] switchChain: \(targetChain)")

        delegate?.requestSwitchChain(server: server, currentUrl: nil, callbackID: callbackID, targetChain: targetChain)

        return .fail(PromiseError(error: DelayWalletConnectResponseError()))
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

        if error.isCancellationError {
            //no-op
        } else {
            displayErrorMessage(error.localizedDescription)
        }
    }

    func provider(_ provider: WalletConnectProvider, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {
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

    func provider(_ provider: WalletConnectProvider, shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal, completion: @escaping (AlphaWallet.WalletConnect.ProposalResponse) -> Void) {
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

    private func showAskSendRawTransaction(title: String, message: String) -> Promise<Bool> {
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
