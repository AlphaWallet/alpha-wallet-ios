// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

protocol TokensCoordinatorDelegate: class, CanOpenURL {
    func didPress(for type: PaymentFlow, server: RPCServer, in coordinator: TokensCoordinator)
    func didTap(transaction: Transaction, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
}

fileprivate struct NoContractDetailsDetected: Error {
}

class TokensCoordinator: Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let tokenCollection: TokenCollection
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>
    private let assetDefinitionStore: AssetDefinitionStore
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
    private let autoDetectTransactedTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Transacted Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let autoDetectTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
                sessions: sessions,
                account: sessions.anyValue.account,
                tokenCollection: tokenCollection,
                assetDefinitionStore: assetDefinitionStore
        )
        controller.delegate = self
        return controller
    }()

    private var newTokenViewController: NewTokenViewController?
    private var addressToAutoDetectServerFor: AlphaWallet.Address?

    private var singleChainTokenCoordinators: [SingleChainTokenCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTokenCoordinator }
    }

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?

    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()

    init(
            navigationController: UINavigationController = NavigationController(),
            sessions: ServerDictionary<WalletSession>,
            keystore: Keystore,
            tokenCollection: TokenCollection,
            nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.sessions = sessions
        self.keystore = keystore
        self.tokenCollection = tokenCollection
        self.nativeCryptoCurrencyPrices = nativeCryptoCurrencyPrices
        self.assetDefinitionStore = assetDefinitionStore
        setupSingleChainTokenCoordinators()
    }

    func start() {
        for each in singleChainTokenCoordinators {
            each.start()
        }
        showTokens()
    }

    private func setupSingleChainTokenCoordinators() {
        for each in tokenCollection.tokenDataStores {
            let server = each.server
            let session = sessions[server]
            let price = nativeCryptoCurrencyPrices[server]
            let coordinator = SingleChainTokenCoordinator(session: session, keystore: keystore, tokensStorage: each, ethPrice: price, assetDefinitionStore: assetDefinitionStore, navigationController: navigationController, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue)
            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    private func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    func addImportedToken(forContract contract: AlphaWallet.Address, server: RPCServer) {
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        coordinator.addImportedToken(forContract: contract)
    }

    private func createNewTokenViewController() -> NewTokenViewController {
        serverToAddCustomTokenOn = .auto
        let controller = NewTokenViewController(server: serverToAddCustomTokenOn)
        controller.delegate = self
        return controller
    }

    @objc func addToken() {
        let controller = createNewTokenViewController()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .formSheet
        navigationController.present(nav, animated: true, completion: nil)
        newTokenViewController = controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        return singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    private func showServers(inViewController viewController: UIViewController) {
        let coordinator = ServersCoordinator(defaultServer: serverToAddCustomTokenOn)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        viewController.present(UINavigationController(rootViewController: coordinator.serversViewController), animated: true)
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

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensViewController.listOfBadTokenScriptFiles = fileNames
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didSelect(token: TokenObject, in viewController: UIViewController) {
        let server = token.server
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        switch token.type {
        case .nativeCryptocurrency:
            coordinator.show(fungibleToken: token, transferType: .nativeCryptocurrency(server: server, destination: .none, amount: nil))
        case .erc20:
            coordinator.show(fungibleToken: token, transferType: .ERC20Token(token, destination: nil, amount: nil))
        case .erc721:
            coordinator.showTokenList(for: .send(type: .ERC721Token(token)), token: token)
        case .erc875:
            coordinator.showTokenList(for: .send(type: .ERC875Token(token)), token: token)
        }
    }

    func didDelete(token: TokenObject, in viewController: UIViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.delete(token: token)
    }

    func didTapOpenConsole(in viewController: UIViewController) {
        delegate?.openConsole(inCoordinator: self)
    }

    func didPressAddToken(in viewController: UIViewController) {
        addToken()
    }
}

extension TokensCoordinator: NewTokenViewControllerDelegate {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.add(token: token)
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

    func didTapChangeServer(in viewController: NewTokenViewController) {
        showServers(inViewController: viewController)
    }
}

func -<T: Equatable>(left: [T], right: [T]) -> [T] {
    return left.filter { l in
        !right.contains { $0 == l }
    }
}

extension TokensCoordinator: SingleChainTokenCoordinatorDelegate {
    func tokensDidChange(inCoordinator coordinator: SingleChainTokenCoordinator) {
        tokensViewController.fetch()
    }

    func didPress(for type: PaymentFlow, inCoordinator coordinator: SingleChainTokenCoordinator) {
        delegate?.didPress(for: type, server: coordinator.session.server, in: self)
    }

    func didTap(transaction: Transaction, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(transaction: transaction, inViewController: viewController, in: self)
    }
}

extension TokensCoordinator: CanOpenURL {
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

extension TokensCoordinator: ServersCoordinatorDelegate {
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
