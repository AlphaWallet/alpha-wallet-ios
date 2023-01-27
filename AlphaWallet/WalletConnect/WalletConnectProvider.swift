//
//  WalletConnectProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletFoundation
import AlphaWalletLogger
import PromiseKit
import AlphaWalletCore

protocol WalletConnectProviderDelegate: AnyObject {
    func provider(_ provider: WalletConnectProvider, didConnect session: AlphaWallet.WalletConnect.Session)
    func provider(_ provider: WalletConnectProvider, shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal, completion: @escaping (AlphaWallet.WalletConnect.ProposalResponse) -> Void)

    func requestGetTransactionCount(session: WalletSession) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestSignMessage(message: SignMessageType,
                            account: AlphaWallet.Address,
                            requester: RequesterViewModel) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestSendRawTransaction(session: WalletSession,
                                   requester: DappRequesterViewModel,
                                   transaction: String,
                                   configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestSendTransaction(session: WalletSession,
                                requester: DappRequesterViewModel,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestSingTransaction(session: WalletSession,
                                requester: DappRequesterViewModel,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestAddCustomChain(server: RPCServer,
                               callbackId: SwitchCustomChainCallbackId,
                               customChain: WalletAddEthereumChainObject) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func requestSwitchChain(server: RPCServer,
                            currentUrl: URL?,
                            callbackID: SwitchCustomChainCallbackId,
                            targetChain: WalletSwitchEthereumChainObject) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError>

    func provider(_ provider: WalletConnectProvider, didFail error: WalletConnectError)
    func provider(_ provider: WalletConnectProvider, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)
}

final class WalletConnectProvider: NSObject {
    private let services: CurrentValueSubject<[WalletConnectServer], Never> = .init([])
    private let sessionsSubject: CurrentValueSubject<[AlphaWallet.WalletConnect.Session], Never> = .init([])
    private var cancellable = Set<AnyCancellable>()
    private let keystore: Keystore
    private let config: Config
    private let dependencies: AtomicDictionary<Wallet, AppCoordinator.WalletDependencies>

    var sessions: [AlphaWallet.WalletConnect.Session] {
        return sessionsSubject.value
    }

    var sessionsPublisher: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> {
        sessionsSubject.eraseToAnyPublisher()
    }

    weak var delegate: WalletConnectProviderDelegate?

    init(keystore: Keystore,
         config: Config,
         dependencies: AtomicDictionary<Wallet, AppCoordinator.WalletDependencies>) {

        self.dependencies = dependencies
        self.keystore = keystore
        self.config = config
        super.init()

        services
            .flatMapLatest { $0.map { $0.sessions }.combineLatest() }
            .map { $0.flatMap { $0 } }
            .assign(to: \.value, on: sessionsSubject)
            .store(in: &cancellable)
    }

    func register(service: WalletConnectServer) {
        service.delegate = self
        services.value.append(service)
    }

    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        for each in services.value {
            try each.respond(response, request: request)
        }
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        for each in services.value {
            try each.connect(url: url)
        }
    }

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws {
        for each in services.value {
            try each.update(topicOrUrl, servers: servers)
        }
    }

    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        for each in services.value {
            try each.disconnect(topicOrUrl)
        }
    }

    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        return services.value.contains(where: { $0.isConnected(topicOrUrl) })
    }

    func responseServerChangeSucceed(request: AlphaWallet.WalletConnect.Session.Request) throws {
        return try respond(.value(nil), request: request)
    }

    //NOTE: even when we received `wallet_switchEthereumChain` and returned to served null as successfull response it doesn't cause server change in the dapp
    //we have to send swith server request manually
    //WARNING: tweak for WalletConnect v2 as it might accept several servers at once
    func notifyUpdateServers(request: AlphaWallet.WalletConnect.Session.Request, server: RPCServer) throws {
        try update(request.topicOrUrl, servers: [server])
    }
}

extension WalletConnectProvider: WalletConnectServerDelegate {

    func server(_ server: WalletConnectServer,
                didConnect session: AlphaWallet.WalletConnect.Session) {

        delegate?.provider(self, didConnect: session)
    }

    func server(_ server: WalletConnectServer,
                shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal,
                completion: @escaping (AlphaWallet.WalletConnect.ProposalResponse) -> Void) {

        delegate?.provider(self, shouldConnectFor: proposal, completion: completion)
    }

    func server(_ server: WalletConnectServer,
                action: AlphaWallet.WalletConnect.Action,
                request: AlphaWallet.WalletConnect.Session.Request,
                session: AlphaWallet.WalletConnect.Session) {

        infoLog("[WalletConnect] action: \(action)")

        do {
            let wallet = try self.wallet(session: session)

            guard let dep = dependencies[wallet] else { throw PMKError.cancelled }
            guard let walletSession = request.server.flatMap({ dep.sessionsProvider.session(for: $0) }) else { throw PMKError.cancelled }

            let requester = DappRequesterViewModel(requester: Requester(walletConnectSession: session, request: request))

            buildOperation(for: action, walletSession: walletSession, dep: dep, request: request, session: session, requester: requester)
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        if error.embedded is DelayWalletConnectResponseError {
                            //no-op
                        } else {
                            self.delegate?.provider(self, didFail: WalletConnectError(error: error.embedded))
                            try? server.respond(.init(error: .requestRejected), request: request)
                        }
                    }
                    JumpBackToPreviousApp.goBack(forWalletConnectAction: action)
                }, receiveValue: { response in
                    try? server.respond(response, request: request)
                }).store(in: &cancellable)
        } catch {
            JumpBackToPreviousApp.goBack(forWalletConnectAction: action)

            delegate?.provider(self, didFail: WalletConnectError(error: error))
            try? server.respond(.init(error: .requestRejected), request: request)
        }
    }

    func server(_ server: WalletConnectServer, didFail error: Error) {
        delegate?.provider(self, didFail: WalletConnectError(error: error))
    }

    func server(_ server: WalletConnectServer,
                tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {

        delegate?.provider(self, tookTooLongToConnectToUrl: url)
    }

    /// Returns first available wallet matched in session, basically there always one address, but could support multiple in future
    private func wallet(session: AlphaWallet.WalletConnect.Session) throws -> Wallet {
        guard let wallet = keystore.wallets.filter({ addr in session.accounts.contains(where: { $0 == addr.address }) }).first else {
            throw WalletConnectError.walletsNotFound(addresses: session.accounts)
        }

        switch wallet.type {
        case .real: break
        case .watch:
            if config.development.shouldPretendIsRealWallet {
                break
            } else {
                throw WalletConnectError.onlyForWatchWallet(address: wallet.address)
            }
        }

        return wallet
    }

    private func addCustomChain(object customChain: WalletAddEthereumChainObject,
                                request: AlphaWallet.WalletConnect.Session.Request,
                                walletConnectSession: AlphaWallet.WalletConnect.Session) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {
        guard let dappRequestProvider = delegate else { return .fail(PromiseError(error: PMKError.cancelled)) }

        infoLog("[WalletConnect] addCustomChain: \(customChain)")
        guard let server = walletConnectSession.servers.first else {
            return .fail(PromiseError(error: AlphaWallet.WalletConnect.ResponseError.requestRejected))
        }

        let callbackId: SwitchCustomChainCallbackId = .walletConnect(request: request)
        return dappRequestProvider.requestAddCustomChain(server: server, callbackId: callbackId, customChain: customChain)
    }

    private func switchChain(object targetChain: WalletSwitchEthereumChainObject,
                             request: AlphaWallet.WalletConnect.Session.Request,
                             walletConnectSession: AlphaWallet.WalletConnect.Session,
                             dep: AppCoordinator.WalletDependencies) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {

        guard let dappRequestProvider = delegate else { return .fail(PromiseError(error: PMKError.cancelled)) }

        infoLog("[WalletConnect] switchChain: \(targetChain)")

        //NOTE: DappRequestSwitchExistingChainCoordinator requires current selected server, (from dapp impl) if we pass server that isn't currently selected it will ask to switch server 2 times, for this we return server that is already selected
        func firstEnabledRPCServer() -> RPCServer? {
            let server = targetChain.server.flatMap { dep.sessionsProvider.session(for: $0)?.server }

            return server ?? walletConnectSession.servers.first
        }

        guard let server = firstEnabledRPCServer(), targetChain.server != nil else {
            //TODO: implement switch chain if its available, but disabled
            return .fail(PromiseError(error: AlphaWallet.WalletConnect.ResponseError.unsupportedChain(chainId: targetChain.chainId)))
        }

        let callbackID: SwitchCustomChainCallbackId = .walletConnect(request: request)

        return dappRequestProvider.requestSwitchChain(server: server, currentUrl: nil, callbackID: callbackID, targetChain: targetChain)
    }

    private func buildOperation(for action: AlphaWallet.WalletConnect.Action,
                                walletSession: WalletSession,
                                dep: AppCoordinator.WalletDependencies,
                                request: AlphaWallet.WalletConnect.Session.Request,
                                session: AlphaWallet.WalletConnect.Session,
                                requester: DappRequesterViewModel) -> AnyPublisher<AlphaWallet.WalletConnect.Response, PromiseError> {

        guard let dappRequestProvider = delegate else { return .fail(PromiseError(error: PMKError.cancelled)) }

        switch action.type {
        case .signTransaction(let transaction):
            return dappRequestProvider.requestSingTransaction(
                session: walletSession,
                requester: requester,
                transaction: transaction,
                configuration: .walletConnect(confirmType: .sign, requester: requester))
        case .sendTransaction(let transaction):
            return dappRequestProvider.requestSendTransaction(
                session: walletSession,
                requester: requester,
                transaction: transaction,
                configuration: .walletConnect(confirmType: .signThenSend, requester: requester))
        case .signMessage(let hexMessage):
            return dappRequestProvider.requestSignMessage(
                message: .message(hexMessage.asSignableMessageData),
                account: walletSession.account.address,
                requester: requester)
        case .signPersonalMessage(let hexMessage):
            return dappRequestProvider.requestSignMessage(
                message: .personalMessage(hexMessage.asSignableMessageData),
                account: walletSession.account.address,
                requester: requester)
        case .signTypedMessageV3(let typedData):
            return dappRequestProvider.requestSignMessage(
                message: .eip712v3And4(typedData),
                account: walletSession.account.address,
                requester: requester)
        case .typedMessage(let typedData):
            return dappRequestProvider.requestSignMessage(
                message: .typedMessage(typedData),
                account: walletSession.account.address,
                requester: requester)
        case .sendRawTransaction(let transaction):
            return dappRequestProvider.requestSendRawTransaction(
                session: walletSession,
                requester: requester,
                transaction: transaction,
                configuration: .approve)
        case .getTransactionCount:
            return dappRequestProvider.requestGetTransactionCount(session: walletSession)
        case .unknown:
            return .fail(PromiseError(error: AlphaWallet.WalletConnect.ResponseError.requestRejected))
        case .walletAddEthereumChain(let object):
            return addCustomChain(object: object, request: request, walletConnectSession: session)
        case .walletSwitchEthereumChain(let object):
            return switchChain(object: object, request: request, walletConnectSession: session, dep: dep)
        }
    }
}

class JumpBackToPreviousApp {
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

extension AlphaWallet.WalletConnect.Action.ActionType {
    var shouldGoBackToPreviousAppAfterAction: Bool {
        switch self {
        case .signMessage, .signPersonalMessage, .signTypedMessageV3, .signTransaction, .sendTransaction, .typedMessage, .sendRawTransaction, .walletSwitchEthereumChain, .walletAddEthereumChain:
            return true
        case .getTransactionCount, .unknown:
            return false
        }
    }
}
