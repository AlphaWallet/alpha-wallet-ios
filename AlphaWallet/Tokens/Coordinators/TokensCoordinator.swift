// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

protocol TokensCoordinatorDelegate: class, CanOpenURL {
    func didPress(for type: PaymentFlow, server: RPCServer, in coordinator: TokensCoordinator)
    func didTap(transaction: Transaction, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
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
                tokenCollection: tokenCollection
        )
        controller.delegate = self
        return controller
    }()

    private var newTokenViewController: NewTokenViewController?
    private var addressToAutoDetectServerFor: String?

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
        autoDetectTransactedTokens()
        autoDetectPartnerTokens()
        showTokens()
        refreshUponAssetDefinitionChanges()
    }

    func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }
    
    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribe { [weak self] _ in
            self?.storage.fetchTokenNamesForNonFungibleTokensIfEmpty()
        }
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTransactedTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
            return
        }

        guard let address = keystore.recentlyUsedWallet?.address else { return }
        GetContractInteractions().getContractList(address: address.eip55String, chainId: session.config.chainID) { [weak self] contracts in
            guard let strongSelf = self else { return }
            guard let currentAddress = strongSelf.keystore.recentlyUsedWallet?.address, currentAddress.eip55String.sameContract(as: address.eip55String) else { return }
            let detectedContracts = contracts.map { $0.lowercased() }
            let alreadyAddedContracts = strongSelf.storage.enabledObject.map { $0.address.eip55String.lowercased() }
            let deletedContracts = strongSelf.storage.deletedContracts.map { $0.contract.lowercased() }
            let hiddenContracts = strongSelf.storage.hiddenContracts.map { $0.contract.lowercased() }
            let delegateContracts = strongSelf.storage.delegateContracts.map { $0.contract.lowercased() }
            let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
            var contractsPulled = 0
            var hasRefreshedAfterAddingAllContracts = false
            DispatchQueue.global().async { [weak self] in
                guard let strongSelf = self else { return }
                for eachContract in contractsToAdd {
                    strongSelf.addToken(for: eachContract) {
                        contractsPulled += 1
                        if contractsPulled == contractsToAdd.count {
                            hasRefreshedAfterAddingAllContracts = true
                            DispatchQueue.main.async {
                                strongSelf.tokensViewController.fetch()
                            }
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if !hasRefreshedAfterAddingAllContracts {
                        strongSelf.tokensViewController.fetch()
                    }
                }
            }
        }
    }

    private func autoDetectPartnerTokens() {
        switch session.config.server {
        case .main:
            autoDetectMainnetPartnerTokens()
        case .xDai:
            autoDetectXDaiPartnerTokens()
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .custom:
            break
        }

    }

    private func autoDetectMainnetPartnerTokens() {
        autoDetectTokens(withContracts: Constants.partnerContracts)
    }

    private func autoDetectXDaiPartnerTokens() {
        autoDetectTokens(withContracts: Constants.ethDenverXDaiPartnerContracts)
    }

    private func addERC20Balance(address: Address, contract: Address) {
        let balanceCoordinator = GetBalanceCoordinator(config: session.config)
        balanceCoordinator.getBalance(for: address, contract: contract) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let balance):
                if balance > 0 {
                    strongSelf.addToken(for: contract.eip55String) {
                        DispatchQueue.main.async {
                            strongSelf.tokensViewController.fetch()
                        }
                    }
                }
            case .failure:
                break
            }
        }
    }

    private func addERC875Balance(address: Address, contract: Address) {
        let balanceCoordinator = GetERC875BalanceCoordinator(config: session.config)
        balanceCoordinator.getERC875TokenBalance(for: address, contract: contract) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let balance):
                if !balance.isEmpty {
                    strongSelf.addToken(for: contract.eip55String) {
                        DispatchQueue.main.async {
                            strongSelf.tokensViewController.fetch()
                        }
                    }
                }
            case .failure:
                break
            }
        }
    }

    private func autoDetectTokens(withContracts contractsToDetect: [(name: String, contract: String)]) {
        guard let address = keystore.recentlyUsedWallet?.address else { return }
        let alreadyAddedContracts = storage.enabledObject.map { $0.address.eip55String.lowercased() }
        let deletedContracts = storage.deletedContracts.map { $0.contract.lowercased() }
        let hiddenContracts = storage.hiddenContracts.map { $0.contract.lowercased() }
        let contracts = contractsToDetect.map { $0.contract.lowercased() } - alreadyAddedContracts - deletedContracts - hiddenContracts
        for each in contracts {
            guard let contract = Address(string: each) else { continue }
            storage.getTokenType(for: each) { result in
                switch result {
                    case .erc20:
                        self.addERC20Balance(address: address, contract: contract)
                        break
                    case .erc875:
                        self.addERC875Balance(address: address, contract: contract)
                        break
                    default: break
                }
            }
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

    func addImportedToken(forContract contract: String, server: RPCServer) {
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

    private func fetchContractDataPromise(forServer server: RPCServer, address: String, inViewController viewController: NewTokenViewController) -> Promise<TokenType> {
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

    private func fetchContractData(forServer server: RPCServer, address: String, inViewController viewController: NewTokenViewController) {
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
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didSelect(token: TokenObject, in viewController: UIViewController) {
        let server = token.server
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        let config = sessions[server].config
        switch token.type {
        case .nativeCryptocurrency:
            coordinator.show(fungibleToken: token, transferType: .nativeCryptocurrency(server: server, destination: .none))
        case .erc20:
            coordinator.show(fungibleToken: token, transferType: .ERC20Token(token))
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

    func didAddAddress(address: String, in viewController: NewTokenViewController) {
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
    func didPressViewContractWebPage(forContract contract: String, server: RPCServer, in viewController: UIViewController) {
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
