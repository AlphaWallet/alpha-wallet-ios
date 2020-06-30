// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import RealmSwift
import PromiseKit

private struct NoContractDetailsDetected: Error {
}

protocol AddHideTokensCoordinatorDelegate: class {
    func didClose(coordinator: AddHideTokensCoordinator)
}

class AddHideTokensCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private var viewModel: AddHideTokensViewModel

    private lazy var viewController: AddHideTokensViewController = .init(
        viewModel: viewModel,
        sessions: sessions,
        assetDefinitionStore: assetDefinitionStore
    )

    private let tokenCollection: TokenCollection
    private let sessions: ServerDictionary<WalletSession>
    private let filterTokensCoordinator: FilterTokensCoordinator
    private let assetDefinitionStore: AssetDefinitionStore
    private var newTokenViewController: NewTokenViewController?
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

    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(tokens: [TokenObject], assetDefinitionStore: AssetDefinitionStore, filterTokensCoordinator: FilterTokensCoordinator, tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]], sessions: ServerDictionary<WalletSession>, navigationController: UINavigationController, tokenCollection: TokenCollection, config: Config, singleChainTokenCoordinators: [SingleChainTokenCoordinator]) {
        self.config = config
        self.filterTokensCoordinator = filterTokensCoordinator
        self.sessions = sessions

        self.navigationController = navigationController
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.singleChainTokenCoordinators = singleChainTokenCoordinators
        self.viewModel = AddHideTokensViewModel(
            tokens: tokens,
            tickers: tickers,
            filterTokensCoordinator: filterTokensCoordinator
        )
        viewController.delegate = self
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func addToken() {
        let controller = createNewTokenViewController()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        let nav = UINavigationController(rootViewController: controller)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            nav.modalPresentationStyle = .formSheet
        case .unspecified, .tv, .carPlay, .phone:
            nav.makePresentationFullScreenForiOS13Migration()
        }
        navigationController.present(nav, animated: true, completion: nil)
        newTokenViewController = controller
    }

    private func createNewTokenViewController() -> NewTokenViewController {
        serverToAddCustomTokenOn = .auto
        let controller = NewTokenViewController(server: serverToAddCustomTokenOn)
        controller.delegate = self
        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    private func showServers(inViewController viewController: UIViewController) {
        let coordinator = ServersCoordinator(defaultServer: serverToAddCustomTokenOn, config: config)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        let nc = UINavigationController(rootViewController: coordinator.serversViewController)
        nc.makePresentationFullScreenForiOS13Migration()
        viewController.present(nc, animated: true)
    }
}

extension AddHideTokensCoordinator: NewTokenViewControllerDelegate {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        let token = coordinator.add(token: token)

        viewModel.add(token: token)

        self.viewController.reload()
        
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
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return .init() { _ in } }
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
                    viewController.updateBalanceValue(balance)
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
            case .balance(let balance):
                viewController.updateBalanceValue(balance)
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
        guard let nc = controller.navigationController else { return }
        guard nc.ensureHasDeviceAuthorization() else { return }
        let coordinator = ScanQRCodeCoordinator(navigationController: nc)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}

extension AddHideTokensCoordinator: AddHideTokensViewControllerDelegate {
    func didChangeOrder(tokens: [TokenObject], in viewController: UIViewController) {
        guard let token = tokens.first else { return }
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.updateOrderedTokens(with: tokens)
    }

    func didMark(token: TokenObject, in viewController: UIViewController, isHidden: Bool) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.mark(token: token, isHidden: isHidden)
    }

    func didPressAddToken(in viewController: UIViewController) {
        addToken()
    }

    func didClose(viewController: AddHideTokensViewController) {
        delegate?.didClose(coordinator: self)
    }
}

extension AddHideTokensCoordinator: ServersCoordinatorDelegate {
    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator) {
        serverToAddCustomTokenOn = server
        coordinator.serversViewController.navigationController?.dismiss(animated: true) { [weak self] in
            guard let strongSelf = self else { return }
            guard let vc = strongSelf.newTokenViewController else { return }
            vc.server = strongSelf.serverToAddCustomTokenOn
            vc.configure()
            vc.redetectToken()
        }

        removeCoordinator(coordinator)
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        coordinator.serversViewController.navigationController?.dismiss(animated: true)
        removeCoordinator(coordinator)
    }
}

extension AddHideTokensCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        newTokenViewController?.didScanQRCode(result)
    }
}
