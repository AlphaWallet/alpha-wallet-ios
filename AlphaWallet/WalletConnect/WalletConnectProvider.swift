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
import AlphaWalletCore

protocol WalletConnectProviderDelegate: AnyObject, DappRequesterDelegate {
    func provider(_ provider: WalletConnectProvider,
                  didConnect session: AlphaWallet.WalletConnect.Session)

    func provider(_ provider: WalletConnectProvider,
                  shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal) -> AnyPublisher<AlphaWallet.WalletConnect.ProposalResponse, Never>

    func provider(_ provider: WalletConnectProvider,
                  didFail error: WalletConnectError)

    func provider(_ provider: WalletConnectProvider,
                  tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)

    func provider(_ provider: WalletConnectProvider, shouldAccept authRequest: AlphaWallet.WalletConnect.AuthRequest) -> AnyPublisher<AlphaWallet.WalletConnect.AuthRequestResponse, Never>
}

final class WalletConnectProvider: NSObject {
    typealias ResponsePublisher = AnyPublisher<AlphaWallet.WalletConnect.Response, WalletConnectError>

    private let services: CurrentValueSubject<[WalletConnectServer], Never> = .init([])
    private let sessionsSubject: CurrentValueSubject<[AlphaWallet.WalletConnect.Session], Never> = .init([])
    private var cancellable = Set<AnyCancellable>()
    private let keystore: Keystore
    private let config: Config
    private let dependencies: WalletDependenciesProvidable

    var sessions: [AlphaWallet.WalletConnect.Session] {
        return sessionsSubject.value
    }

    var sessionsPublisher: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> {
        sessionsSubject.eraseToAnyPublisher()
    }

    weak var delegate: WalletConnectProviderDelegate?

    init(keystore: Keystore,
         config: Config,
         dependencies: WalletDependenciesProvidable) {

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

    //NOTE: even when we received `wallet_switchEthereumChain` and returned to served null as successfull response it doesn't cause server change in the dapp
    //we have to send swith server request manually
    //WARNING: tweak for WalletConnect v2 as it might accept several servers at once
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
}

extension WalletConnectProvider: WalletConnectServerDelegate {

    func server(_ server: WalletConnectServer,
                didConnect session: AlphaWallet.WalletConnect.Session) {

        delegate?.provider(self, didConnect: session)
    }

    func server(_ server: WalletConnectServer,
                shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal) -> AnyPublisher<AlphaWallet.WalletConnect.ProposalResponse, Never> {

        guard let delegate = delegate else { return .empty() }

        return delegate.provider(self, shouldConnectFor: proposal)
    }

    func server(_ server: WalletConnectServer,
                action: AlphaWallet.WalletConnect.Action,
                request: AlphaWallet.WalletConnect.Session.Request,
                session: AlphaWallet.WalletConnect.Session) {

        infoLog("[WalletConnect] action: \(action)")

        do {
            let wallet = try wallet(session: session, action: action)

            guard let dep = dependencies.walletDependencies(walletAddress: wallet.address) else { throw WalletConnectError.cancelled }
            guard let walletSession = request.server.flatMap({ dep.sessionsProvider.session(for: $0) }) else { throw WalletConnectError.cancelled }

            let requester = DappRequesterViewModel(requester: Requester(walletConnectSession: session, request: request))

            buildOperation(for: action, walletSession: walletSession, dep: dep, request: request, session: session, requester: requester)
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        switch error {
                        case .internal, .cancelled, .walletsNotFound, .onlyForWatchWallet, .callbackIdMissing, .connectionFailure:
                            self.delegate?.provider(self, didFail: error)
                            try? server.respond(.init(error: error.asJsonRpcError), request: request)
                            JumpBackToPreviousApp.goBack(forWalletConnectAction: action)
                        case .delayedOperation:
                            break
                        }
                    } else {
                        JumpBackToPreviousApp.goBack(forWalletConnectAction: action)
                    }
                }, receiveValue: { response in
                    try? server.respond(response, request: request)
                }).store(in: &cancellable)
        } catch let error as WalletConnectError {
            JumpBackToPreviousApp.goBack(forWalletConnectAction: action)

            delegate?.provider(self, didFail: error)
            try? server.respond(.init(error: error.asJsonRpcError), request: request)
        } catch { /*no-op*/ }
    }

    func server(_ server: WalletConnectServer, didFail error: Error) {
        delegate?.provider(self, didFail: WalletConnectError(error: PromiseError(error: error)))
    }

    func server(_ server: WalletConnectServer,
                tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl) {

        delegate?.provider(self, tookTooLongToConnectToUrl: url)
    }

    func server(_ server: WalletConnectServer, shouldAuthFor authRequest: AlphaWallet.WalletConnect.AuthRequest) -> AnyPublisher<AlphaWallet.WalletConnect.AuthRequestResponse, Never> {
        guard let delegate = delegate else { return .empty() }
        return delegate.provider(self, shouldAccept: authRequest)
    }

    //TODO: extract logic of performing actions in separate provider, dapp browser and wallet connect performing same actions
    /// Returns first available wallet matched in session, basically there always one address, but could support multiple in future
    private func wallet(session: AlphaWallet.WalletConnect.Session, action: AlphaWallet.WalletConnect.Action) throws -> Wallet {
        guard let wallet = keystore.wallets.filter({ addr in session.accounts.contains(where: { $0 == addr.address }) }).first else {
            throw WalletConnectError.walletsNotFound(addresses: session.accounts)
        }

        switch wallet.type {
        case .real, .hardware: break
        case .watch:
            if config.development.shouldPretendIsRealWallet {
                break
            } else {
                switch action.type {
                case .signEip712v3And4, .sendRawTransaction, .typedMessage, .sendTransaction, .signMessage, .signPersonalMessage, .signTransaction:
                    throw WalletConnectError.onlyForWatchWallet(address: wallet.address)
                case .walletAddEthereumChain, .walletSwitchEthereumChain, .getTransactionCount:
                    break
                }
            }
        }

        return wallet
    }

    private func addCustomChain(object customChain: WalletAddEthereumChainObject,
                                request: AlphaWallet.WalletConnect.Session.Request,
                                walletConnectSession: AlphaWallet.WalletConnect.Session) -> ResponsePublisher {

        guard let dappRequestProvider = delegate else { return .fail(.cancelled) }

        infoLog("[WalletConnect] addCustomChain: \(customChain)")
        guard let server = walletConnectSession.servers.first else {
            return .fail(.internal(.requestRejected))
        }

        return dappRequestProvider.requestAddCustomChain(server: server, customChain: customChain)
            .mapError { WalletConnectError(error: $0) }
            .flatMap { [weak self] _ -> ResponsePublisher in
                guard let newServer = customChain.server else { return .empty() }

                try? self?.respond(.init(data: nil), request: request)
                try? self?.update(request.topicOrUrl, servers: [newServer])

                return ResponsePublisher.just(.value(Data()))
            }.eraseToAnyPublisher()
    }

    private func switchChain(object targetChain: WalletSwitchEthereumChainObject,
                             request: AlphaWallet.WalletConnect.Session.Request,
                             walletConnectSession: AlphaWallet.WalletConnect.Session,
                             dep: WalletDependencies) -> ResponsePublisher {

        guard let dappRequestProvider = delegate else { return .fail(.cancelled) }

        infoLog("[WalletConnect] switchChain: \(targetChain)")

        //NOTE: DappRequestSwitchExistingChainCoordinator requires current selected server, (from dapp impl) if we pass server that isn't currently selected it will ask to switch server 2 times, for this we return server that is already selected
        func firstEnabledRPCServer() -> RPCServer? {
            let server = targetChain.server.flatMap { dep.sessionsProvider.session(for: $0)?.server }

            return server ?? walletConnectSession.servers.first
        }

        guard let server = firstEnabledRPCServer(), let newServer = targetChain.server else {
            //TODO: implement switch chain if its available, but disabled
            return .fail(.internal(.unsupportedChain(chainId: targetChain.chainId)))
        }

        return dappRequestProvider.requestSwitchChain(server: server, currentUrl: nil, targetChain: targetChain)
            .mapError { WalletConnectError(error: $0) }
            .flatMap { [weak self] _ -> ResponsePublisher in
                //save order of operations, first we have to respond of request then update session with server
                try? self?.respond(.init(data: nil), request: request)
                try? self?.update(request.topicOrUrl, servers: [newServer])

                return .empty()
            }.eraseToAnyPublisher()
    }

    private func validateMessage(session: AlphaWallet.WalletConnect.Session,
                                 message: SignMessageType,
                                 source: Analytics.SignMessageRequestSource) -> AnyPublisher<Void, PromiseError> {

        do {
            switch message {
            case .eip712v3And4(let typedData):
                let validator = WalletConnectEip712v3And4Validator(session: session, source: source)
                try validator.validate(message: typedData)
            case .typedMessage(let typedData):
                let validator = TypedMessageValidator()
                try validator.validate(message: typedData)
            case .message, .personalMessage:
                break
            }
            return .just(())
        } catch {
            return .fail(PromiseError(error: error))
        }
    }

    // swiftlint:disable function_body_length
    private func buildOperation(for action: AlphaWallet.WalletConnect.Action,
                                walletSession: WalletSession,
                                dep: WalletDependencies,
                                request: AlphaWallet.WalletConnect.Session.Request,
                                session: AlphaWallet.WalletConnect.Session,
                                requester: DappRequesterViewModel) -> ResponsePublisher {

        guard let dappRequestProvider = delegate else { return .fail(.cancelled) }

        switch action.type {
        case .signTransaction(let transaction):
            return dappRequestProvider.requestSignTransaction(
                session: walletSession,
                source: .walletConnect,
                requester: requester,
                transaction: transaction,
                configuration: .walletConnect(confirmType: .sign, requester: requester))
            .mapError { WalletConnectError(error: $0) }
            .map { .value($0) }
            .eraseToAnyPublisher()
        case .sendTransaction(let transaction):
            return dappRequestProvider.requestSendTransaction(
                session: walletSession,
                source: .walletConnect,
                requester: requester,
                transaction: transaction,
                configuration: .walletConnect(confirmType: .signThenSend, requester: requester))
            .mapError { WalletConnectError(error: $0) }
            .map { .value(Data(_hex: $0.id)) }
            .eraseToAnyPublisher()
        case .signMessage(let hexMessage):
            return validateMessage(session: session, message: .message(hexMessage.asSignableMessageData), source: request.source)
                .flatMap { _ in
                    dappRequestProvider.requestSignMessage(
                        message: .message(hexMessage.asSignableMessageData),
                        server: walletSession.server,
                        account: walletSession.account.address,
                        source: request.source,
                        requester: requester)
                }.mapError { WalletConnectError(error: $0) }
                .map { .value($0) }
                .eraseToAnyPublisher()
        case .signPersonalMessage(let hexMessage):
            return validateMessage(session: session, message: .personalMessage(hexMessage.asSignableMessageData), source: request.source)
                .flatMap { _ in
                    dappRequestProvider.requestSignMessage(
                        message: .personalMessage(hexMessage.asSignableMessageData),
                        server: walletSession.server,
                        account: walletSession.account.address,
                        source: request.source,
                        requester: requester)
                }.mapError { WalletConnectError(error: $0) }
                .map { .value($0) }
                .eraseToAnyPublisher()
        case .signEip712v3And4(let typedData):
            return validateMessage(session: session, message: .eip712v3And4(typedData), source: request.source)
                .flatMap { _ in
                    dappRequestProvider.requestSignMessage(
                        message: .eip712v3And4(typedData),
                        server: walletSession.server,
                        account: walletSession.account.address,
                        source: request.source,
                        requester: requester)
                }.mapError { WalletConnectError(error: $0) }
                .map { .value($0) }
                .eraseToAnyPublisher()
        case .typedMessage(let typedData):
            return validateMessage(session: session, message: .typedMessage(typedData), source: request.source)
                .flatMap { _ in
                    dappRequestProvider.requestSignMessage(
                        message: .typedMessage(typedData),
                        server: walletSession.server,
                        account: walletSession.account.address,
                        source: request.source,
                        requester: requester)
                }.mapError { WalletConnectError(error: $0) }
                .map { .value($0) }
                .eraseToAnyPublisher()
        case .sendRawTransaction(let transaction):
            return dappRequestProvider.requestSendRawTransaction(
                session: walletSession,
                source: .walletConnect,
                requester: requester,
                transaction: transaction)
            .mapError { WalletConnectError(error: $0) }
            .map { .value(Data(_hex: $0)) }
            .eraseToAnyPublisher()
        case .getTransactionCount:
            return dappRequestProvider.requestGetTransactionCount(
                session: walletSession,
                source: request.source)
            .mapError { WalletConnectError(error: $0) }
            .map { .value($0) }
            .eraseToAnyPublisher()
        case .walletAddEthereumChain(let object):
            return addCustomChain(object: object, request: request, walletConnectSession: session)
        case .walletSwitchEthereumChain(let object):
            return switchChain(object: object, request: request, walletConnectSession: session, dep: dep)
        }
    }
    // swiftlint:enable function_body_length
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
        case .signMessage, .signPersonalMessage, .signEip712v3And4, .signTransaction, .sendTransaction, .typedMessage, .sendRawTransaction, .walletSwitchEthereumChain, .walletAddEthereumChain:
            return true
        case .getTransactionCount:
            return false
        }
    }
}

extension WalletConnectProvider {
    static func instance(serversProvider: ServersProvidable,
                         keystore: Keystore,
                         dependencies: WalletDependenciesProvidable,
                         config: Config,
                         caip10AccountProvidable: CAIP10AccountProvidable) -> WalletConnectProvider {

        let provider = WalletConnectProvider(
            keystore: keystore,
            config: config,
            dependencies: dependencies)
        let decoder = WalletConnectRequestDecoder()

        let v1Provider = WalletConnectV1Provider(
            caip10AccountProvidable: caip10AccountProvidable,
            client: WalletConnectV1NativeClient(),
            storage: WalletConnectV1Storage(),
            decoder: decoder,
            config: config)

        let v2Provider = WalletConnectV2Provider(
            caip10AccountProvidable: caip10AccountProvidable,
            storage: WalletConnectV2Storage(),
            serversProvider: serversProvider,
            decoder: decoder,
            client: WalletConnectV2NativeClient(keystore: keystore))

        provider.register(service: v1Provider)
        provider.register(service: v2Provider)

        return provider
    }
}
