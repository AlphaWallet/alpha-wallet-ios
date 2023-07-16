//
//  NewTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2020.
//

import UIKit
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletCore

private struct NoContractDetailsDetected: Error {
}

protocol NewTokenCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: Token)
    func didClose(in coordinator: NewTokenCoordinator)
}

class NewTokenCoordinator: Coordinator {

    private var serverToAddCustomTokenOn: RPCServerOrAuto = .auto {
        didSet {
            switch serverToAddCustomTokenOn {
            case .auto:
                break
            case .server:
                addressToAutoDetectServerFor = nil
            }
        }
    }
    private let wallet: Wallet
    private var addressToAutoDetectServerFor: AlphaWallet.Address?
    private let sessionsProvider: SessionsProvider
    private let serversProvider: ServersProvidable
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let navigationController: UINavigationController
    private lazy var viewController: NewTokenViewController = {
        return NewTokenViewController(
            server: serverToAddCustomTokenOn,
            domainResolutionService: domainResolutionService,
            initialState: initialState)
    }()
    private let initialState: NewTokenInitialState
    private var cancellable = Set<AnyCancellable>()

    var coordinators: [Coordinator] = []
    weak var delegate: NewTokenCoordinatorDelegate?

    init(analytics: AnalyticsLogger,
         wallet: Wallet,
         navigationController: UINavigationController,
         serversProvider: ServersProvidable,
         sessionsProvider: SessionsProvider,
         initialState: NewTokenInitialState = .empty,
         domainResolutionService: DomainNameResolutionServiceType) {

        self.serversProvider = serversProvider
        self.wallet = wallet
        self.analytics = analytics
        self.navigationController = navigationController
        self.sessionsProvider = sessionsProvider
        self.initialState = initialState
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func dismiss() {
        navigationController.popViewController(animated: true)
    }

    private func showServers() {
        let coordinator = ServersCoordinator(
            defaultServer: serverToAddCustomTokenOn,
            serversProvider: serversProvider,
            navigationController: navigationController)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension NewTokenCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        switch selection {
        case .server(let server):
            serverToAddCustomTokenOn = server
            viewController.server = serverToAddCustomTokenOn
            viewController.configure()
            viewController.redetectToken()
        case .multipleServers:
            break
        }

        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension NewTokenCoordinator: NewTokenViewControllerDelegate {

    func didClose(viewController: NewTokenViewController) {
        delegate?.didClose(in: self)
    }

    func didAddToken(ercToken: ErcToken, in viewController: NewTokenViewController) {
        guard let session = sessionsProvider.session(for: ercToken.server) else { return }
        Task { @MainActor in
            let token = await session.importToken.importToken(ercToken: ercToken, shouldUpdateBalance: true)
            delegate?.coordinator(self, didAddToken: token)
            dismiss()
        }
    }

    func didAddAddress(address: AlphaWallet.Address, in viewController: NewTokenViewController) {
        switch viewController.server {
        case .auto:
            addressToAutoDetectServerFor = address
            var serversFailed = 0

            //TODO be good if we can check every chain, including those that are not enabled: https://github.com/AlphaWallet/alpha-wallet-ios/issues/1166
            let sessions = sessionsProvider.activeSessions.values
            for session in sessions {
                //It's possible we'll find the contracts with the same address across different chains, but let's not worry about it. User can manually choose a chain if they encounter this
                fetchContractDataPromise(session: session, address: address, in: viewController)
                    .sink(receiveCompletion: { result in
                        guard case .failure = result else { return }
                        serversFailed += 1
                        if serversFailed == sessions.count {
                            //So that we can enable the Done button
                            verboseLog("[TokenType] fallback contract: \(address.eip55String) server: \(session) to token type: erc20")
                            viewController.updateForm(forTokenType: .erc20)
                        }
                    }, receiveValue: { [weak self] tokenType in
                        self?.serverToAddCustomTokenOn = .server(session.server)
                        viewController.updateForm(forTokenType: tokenType)
                        viewController.server = .server(session.server)
                        viewController.configure()
                    }).store(in: &cancellable)
            }
        case .server(let server):
            guard let session = sessionsProvider.session(for: server) else { return }
            fetchContractData(session: session, address: address, in: viewController)
        }
    }

    private func fetchContractDataPromise(session: WalletSession,
                                          address: AlphaWallet.Address,
                                          in viewController: NewTokenViewController) -> AnyPublisher<TokenType, PromiseError> {
        let server = session.server

        return session.importToken.fetchContractData(for: address)
            .receive(on: RunLoop.main)
            .setFailureType(to: PromiseError.self)
            .flatMap {  data -> AnyPublisher<TokenType, PromiseError> in
                guard self.addressToAutoDetectServerFor == address else { return .empty() }
                switch data {
                case .name, .symbol, .balance, .decimals:
                    return .empty()
                case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                    viewController.updateNameValue(name)
                    viewController.updateSymbolValue(symbol)
                    viewController.updateBalanceValue(balance, tokenType: tokenType)
                    verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: nonFungibleTokenComplete")

                    return .just(tokenType)
                case .fungibleTokenComplete(let name, let symbol, let decimals, _, let tokenType):
                    viewController.updateNameValue(name)
                    viewController.updateSymbolValue(symbol)
                    viewController.updateDecimalsValue(decimals)
                    verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: fungibleTokenComplete")

                    return .just(tokenType)
                case .delegateTokenComplete:
                    verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: delegateTokenComplete")
                    return .fail(PromiseError(error: NoContractDetailsDetected()))
                case .failed:
                    verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) failed")
                    return .fail(PromiseError(error: NoContractDetailsDetected()))
                }
            }.eraseToAnyPublisher()
    }

    private func fetchContractData(session: WalletSession, address: AlphaWallet.Address, in viewController: NewTokenViewController) {
        session.importToken
            .fetchContractData(for: address)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { data in
                switch data {
                case .name(let name):
                    viewController.updateNameValue(name)
                case .symbol(let symbol):
                    viewController.updateSymbolValue(symbol)
                case .balance(let nonFungibleBalance, _, let tokenType):
                    if let balance = nonFungibleBalance {
                        viewController.updateBalanceValue(balance, tokenType: tokenType)
                    }
                case .decimals(let decimals):
                    viewController.updateDecimalsValue(decimals)
                case .nonFungibleTokenComplete(_, _, _, let tokenType):
                    viewController.updateForm(forTokenType: tokenType)
                case .fungibleTokenComplete:
                    viewController.updateForm(forTokenType: .erc20)
                case .delegateTokenComplete:
                    viewController.updateForm(forTokenType: .erc20)
                case .failed:
                    break
                }
            }).store(in: &cancellable)
    }

    func didTapChangeServer(in viewController: NewTokenViewController) {
        showServers()
    }

    func openQRCode(in controller: NewTokenViewController) {
        guard let nc = controller.navigationController, nc.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: wallet,
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start(fromSource: .addCustomTokenScreen)
    }
}

extension NewTokenCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        viewController.didScanQRCode(result)
    }
}
