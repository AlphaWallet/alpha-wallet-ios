//
//  NewTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2020.
//

import UIKit
import RealmSwift
import PromiseKit

private struct NoContractDetailsDetected: Error {
}

protocol NewTokenCoordinatorDelegate: class {
    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: TokenObject)
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
    private var addressToAutoDetectServerFor: AlphaWallet.Address?
    private let singleChainTokenCoordinators: [SingleChainTokenCoordinator]
    private let config: Config
    private let tokenCollection: TokenCollection
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private lazy var viewController: NewTokenViewController = .init(server: serverToAddCustomTokenOn, initialState: initialState)
    private let initialState: NewTokenInitialState
    private let sessions: ServerDictionary<WalletSession>
    var coordinators: [Coordinator] = []
    weak var delegate: NewTokenCoordinatorDelegate?

    init(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, tokenCollection: TokenCollection, config: Config, singleChainTokenCoordinators: [SingleChainTokenCoordinator], initialState: NewTokenInitialState = .empty, sessions: ServerDictionary<WalletSession>) {
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.tokenCollection = tokenCollection
        self.singleChainTokenCoordinators = singleChainTokenCoordinators
        self.initialState = initialState
        self.sessions = sessions
    }

    func start() {
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func dismiss() {
        navigationController.popViewController(animated: true)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    private func showServers(inViewController viewController: UIViewController) {
        let coordinator = ServersCoordinator(defaultServer: serverToAddCustomTokenOn, config: config, navigationController: navigationController)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension NewTokenCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator) {
        serverToAddCustomTokenOn = server
        coordinator.navigationController.popViewController(animated: true) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.viewController.server = strongSelf.serverToAddCustomTokenOn
            strongSelf.viewController.configure()
            strongSelf.viewController.redetectToken()
        }

        removeCoordinator(coordinator)
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        coordinator.navigationController.popViewController(animated: true)
        removeCoordinator(coordinator)
    }
}

extension NewTokenCoordinator: NewTokenViewControllerDelegate {

    func didClose(viewController: NewTokenViewController) {
        delegate?.didClose(in: self)
    }

    func didAddToken(token: ERCToken, in viewController: NewTokenViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        let token = coordinator.add(token: token)

        delegate?.coordinator(self, didAddToken: token)
        dismiss()
    }

    func didAddAddress(address: AlphaWallet.Address, in viewController: NewTokenViewController) {
        switch viewController.server {
        case .auto:
            addressToAutoDetectServerFor = address
            var serversFailed = 0

            //TODO be good if we can check every chain, including those that are not enabled: https://github.com/AlphaWallet/alpha-wallet-ios/issues/1166
            let servers = tokenCollection.tokenDataStores.map { $0.server }
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
                        viewController.updateForm(forTokenType: .erc20)
                    }
                }
            }
        case .server(let server):
            fetchContractData(forServer: server, address: address, inViewController: viewController)
        }
    }

    private func fetchContractDataPromise(forServer server: RPCServer, address: AlphaWallet.Address, inViewController viewController: NewTokenViewController) -> Promise<TokenType> {
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return .init { _ in } }
        return Promise { seal in
            coordinator.fetchContractData(for: address) { [weak self] (data) in
                guard let strongSelf = self else { return }
                guard strongSelf.addressToAutoDetectServerFor == address else { return }
                switch data {
                case .name, .symbol, .balance, .decimals:
                    break
                case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                    viewController.updateNameValue(name)
                    viewController.updateSymbolValue(symbol)
                    viewController.updateBalanceValue(balance, tokenType: tokenType)
                    seal.fulfill(tokenType)
                case .fungibleTokenComplete(let name, let symbol, let decimals):
                    viewController.updateNameValue(name)
                    viewController.updateSymbolValue(symbol)
                    viewController.updateDecimalsValue(decimals)
                    seal.fulfill(.erc20)
                case .delegateTokenComplete:
                    seal.reject(NoContractDetailsDetected())
                case .failed:
                    seal.reject(NoContractDetailsDetected())
                }
            }
        }
    }

    private func fetchContractData(forServer server: RPCServer, address: AlphaWallet.Address, inViewController viewController: NewTokenViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        coordinator.fetchContractData(for: address) { data in
            switch data {
            case .name(let name):
                viewController.updateNameValue(name)
            case .symbol(let symbol):
                viewController.updateSymbolValue(symbol)
            case .balance(let balance, let tokenType):
                viewController.updateBalanceValue(balance, tokenType: tokenType)
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

    func didTapChangeServer(in viewController: NewTokenViewController) {
        showServers(inViewController: viewController)
    }

    func openQRCode(in controller: NewTokenViewController) {
        guard let nc = controller.navigationController, nc.ensureHasDeviceAuthorization() else { return }

        let account = sessions.anyValue.account
        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: account)
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
