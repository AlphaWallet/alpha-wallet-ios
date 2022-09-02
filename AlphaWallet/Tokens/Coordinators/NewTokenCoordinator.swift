//
//  NewTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2020.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

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
    private var addressToAutoDetectServerFor: AlphaWallet.Address?
    private let importToken: ImportToken
    private let config: Config
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let navigationController: UINavigationController
    private lazy var viewController: NewTokenViewController = .init(server: serverToAddCustomTokenOn, domainResolutionService: domainResolutionService, initialState: initialState)
    private let initialState: NewTokenInitialState
    var coordinators: [Coordinator] = []
    weak var delegate: NewTokenCoordinatorDelegate?

    init(analytics: AnalyticsLogger, navigationController: UINavigationController, config: Config, importToken: ImportToken, initialState: NewTokenInitialState = .empty, domainResolutionService: DomainResolutionServiceType) {
        self.config = config
        self.analytics = analytics
        self.navigationController = navigationController
        self.importToken = importToken
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
            coordinator.navigationController.popViewController(animated: true) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.viewController.server = strongSelf.serverToAddCustomTokenOn
                strongSelf.viewController.configure()
                strongSelf.viewController.redetectToken()
            }
        case .multipleServers:
            break
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
        let token = importToken.importToken(token: token)

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
                        viewController.updateForm(forTokenType: .erc20)
                    }
                }
            }
        case .server(let server):
            fetchContractData(forServer: server, address: address, inViewController: viewController)
        }
    }

    private func fetchContractDataPromise(forServer server: RPCServer, address: AlphaWallet.Address, inViewController viewController: NewTokenViewController) -> Promise<TokenType> {
        return Promise { seal in
            importToken.fetchContractData(for: address, server: server) { [weak self] (data) in
                guard let strongSelf = self else { return }
                guard strongSelf.addressToAutoDetectServerFor == address else { return }
                switch data {
                case .name, .symbol, .balance, .decimals:
                    break
                case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                    viewController.updateNameValue(name)
                    viewController.updateSymbolValue(symbol)
                    viewController.updateBalanceValue(balance.rawValue, tokenType: tokenType)
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
        importToken.fetchContractData(for: address, server: server) { data in
            switch data {
            case .name(let name):
                viewController.updateNameValue(name)
            case .symbol(let symbol):
                viewController.updateSymbolValue(symbol)
            case .balance(let balance, let tokenType):
                viewController.updateBalanceValue(balance.rawValue, tokenType: tokenType)
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

        let coordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: importToken.wallet, domainResolutionService: domainResolutionService)
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
