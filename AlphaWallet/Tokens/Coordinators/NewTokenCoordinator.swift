//
//  NewTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2020.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation
import AlphaWalletLogger

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
    private let config: Config
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let navigationController: UINavigationController
    private lazy var viewController: NewTokenViewController = .init(server: serverToAddCustomTokenOn, domainResolutionService: domainResolutionService, initialState: initialState)
    private let initialState: NewTokenInitialState
    var coordinators: [Coordinator] = []
    weak var delegate: NewTokenCoordinatorDelegate?

    init(analytics: AnalyticsLogger,
         wallet: Wallet,
         navigationController: UINavigationController,
         config: Config,
         sessionsProvider: SessionsProvider,
         initialState: NewTokenInitialState = .empty,
         domainResolutionService: DomainResolutionServiceType) {

        self.config = config
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

    private func showServers(inViewController viewController: UIViewController) {
        let coordinator = ServersCoordinator(defaultServer: serverToAddCustomTokenOn, config: config, navigationController: navigationController)
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
        let token = session.importToken.importToken(ercToken: ercToken, shouldUpdateBalance: true)

        delegate?.coordinator(self, didAddToken: token)
        dismiss()
    }

    func didAddAddress(address: AlphaWallet.Address, in viewController: NewTokenViewController) {
        switch viewController.server {
        case .auto:
            addressToAutoDetectServerFor = address
            var serversFailed = 0

            //TODO be good if we can check every chain, including those that are not enabled: https://github.com/AlphaWallet/alpha-wallet-ios/issues/1166
            let servers = config.enabledServers
            for each in servers {
                //It's possible we'll find the contracts with the same address across different chains, but let's not worry about it. User can manually choose a chain if they encounter this
                fetchContractDataPromise(forServer: each, address: address, inViewController: viewController).done { [weak self] (tokenType) in
                    self?.serverToAddCustomTokenOn = .server(each)
                    viewController.updateForm(forTokenType: tokenType)
                    viewController.server = .server(each)
                    viewController.configure()
                }.catch { _ in
                    serversFailed += 1
                    if serversFailed == servers.count {
                        //So that we can enable the Done button
                        verboseLog("[TokenType] fallback contract: \(address.eip55String) server: \(each) to token type: erc20")
                        viewController.updateForm(forTokenType: .erc20)
                    }
                }
            }
        case .server(let server):
            fetchContractData(forServer: server, address: address, inViewController: viewController)
        }
    }

    private func fetchContractDataPromise(forServer server: RPCServer, address: AlphaWallet.Address, inViewController viewController: NewTokenViewController) -> Promise<TokenType> {
        return Promise { [sessionsProvider] seal in
            guard let session = sessionsProvider.session(for: server) else {
                seal.reject(NoContractDetailsDetected())
                return
            }

            session.importToken.fetchContractData(for: address) { [weak self] (data) in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    guard strongSelf.addressToAutoDetectServerFor == address else { return }
                    switch data {
                    case .name, .symbol, .balance, .decimals:
                        break
                    case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                        viewController.updateNameValue(name)
                        viewController.updateSymbolValue(symbol)
                        viewController.updateBalanceValue(balance.rawValue, tokenType: tokenType)
                        verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: nonFungibleTokenComplete")
                        seal.fulfill(tokenType)
                    case .fungibleTokenComplete(let name, let symbol, let decimals, _, let tokenType):
                        viewController.updateNameValue(name)
                        viewController.updateSymbolValue(symbol)
                        viewController.updateDecimalsValue(decimals)
                        verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: fungibleTokenComplete")
                        seal.fulfill(tokenType)
                    case .delegateTokenComplete:
                        verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) to token type: delegateTokenComplete")
                        seal.reject(NoContractDetailsDetected())
                    case .failed:
                        verboseLog("[TokenType] contract: \(address.eip55String) server: \(server) failed")
                        seal.reject(NoContractDetailsDetected())
                    }
                }
            }
        }
    }

    private func fetchContractData(forServer server: RPCServer, address: AlphaWallet.Address, inViewController viewController: NewTokenViewController) {
        guard let session = sessionsProvider.session(for: server) else { return }
        
        session.importToken.fetchContractData(for: address) { data in
            DispatchQueue.main.async {
                switch data {
                case .name(let name):
                    viewController.updateNameValue(name)
                case .symbol(let symbol):
                    viewController.updateSymbolValue(symbol)
                case .balance(let nonFungibleBalance, _, let tokenType):
                    if let balance = nonFungibleBalance {
                        viewController.updateBalanceValue(balance.rawValue, tokenType: tokenType)
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
            }
        }
    }

    func didTapChangeServer(in viewController: NewTokenViewController) {
        showServers(inViewController: viewController)
    }

    func openQRCode(in controller: NewTokenViewController) {
        guard let nc = controller.navigationController, nc.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: wallet, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start(fromSource: .addCustomTokenScreen)
    }
}

extension NewTokenCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        viewController.didScanQRCode(result)
    }
}
