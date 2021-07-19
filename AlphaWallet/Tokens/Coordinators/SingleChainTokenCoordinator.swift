// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Alamofire
import BigInt
import RealmSwift
import PromiseKit
import Result

enum ContractData {
    case name(String)
    case symbol(String)
    case balance(balance: [String], tokenType: TokenType)
    case decimals(UInt8)
    case nonFungibleTokenComplete(name: String, symbol: String, balance: [String], tokenType: TokenType)
    case fungibleTokenComplete(name: String, symbol: String, decimals: UInt8)
    case delegateTokenComplete
    case failed(networkReachable: Bool?)
}

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

protocol SingleChainTokenCoordinatorDelegate: class, CanOpenURL {
    func tokensDidChange(inCoordinator coordinator: SingleChainTokenCoordinator)
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: SingleChainTokenCoordinator)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: SingleChainTokenCoordinator)
    func didPress(for type: PaymentFlow, inCoordinator coordinator: SingleChainTokenCoordinator)
    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator)
}

// swiftlint:disable type_body_length
class SingleChainTokenCoordinator: Coordinator {
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let cryptoPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let analyticsCoordinator: AnalyticsCoordinator
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private var isAutoDetectingTransactedTokens = false
    private var isAutoDetectingTokens = false
    private let tokenActionsProvider: TokenActionsProvider
    private let transactionsStorage: TransactionsStorage
    private let coinTickersFetcher: CoinTickersFetcherType
    let session: WalletSession
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var server: RPCServer {
        session.server
    }

    init(
            session: WalletSession,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: EventsDataStoreProtocol,
            analyticsCoordinator: AnalyticsCoordinator,
            withAutoDetectTransactedTokensQueue autoDetectTransactedTokensQueue: OperationQueue,
            withAutoDetectTokensQueue autoDetectTokensQueue: OperationQueue,
            tokenActionsProvider: TokenActionsProvider,
            transactionsStorage: TransactionsStorage,
            coinTickersFetcher: CoinTickersFetcherType
    ) {
        self.session = session
        self.keystore = keystore
        self.storage = tokensStorage
        self.cryptoPrice = ethPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
        self.tokenActionsProvider = tokenActionsProvider
        self.transactionsStorage = transactionsStorage
        self.coinTickersFetcher = coinTickersFetcher
    }

    func start() {
        //Since this is called at launch, we don't want it to block launching
        DispatchQueue.global().async {
            DispatchQueue.main.async { [weak self] in
                self?.autoDetectTransactedTokens()
                self?.autoDetectPartnerTokens()
            }
        }
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTransactedTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        guard !isRunningTests() else { return }
        guard !session.config.isAutoFetchingDisabled else { return }
        guard !isAutoDetectingTransactedTokens else { return }

        isAutoDetectingTransactedTokens = true
        let operation = AutoDetectTransactedTokensOperation(forServer: server, coordinator: self, wallet: keystore.currentWallet.address)
        autoDetectTransactedTokensQueue.addOperation(operation)
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<Void> {
        let startBlock: Int?
        if erc20 {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        } else {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        }
        return firstly {
            //TODO why do it on main?
            GetContractInteractions(queue: .main).getContractList(address: wallet, server: server, startBlock: startBlock, erc20: erc20)
        //TODO: watch out for queue used here, accessing Realm
        }.get(on: DispatchQueue.global()) { [weak self] contracts, maxBlockNumber in
            guard let strongSelf = self else { return }
            if let maxBlockNumber = maxBlockNumber {
                if erc20 {
                    Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                } else {
                    Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                }
            }
            let currentAddress = strongSelf.keystore.currentWallet.address
            guard currentAddress.sameContract(as: wallet) else { return }
            let detectedContracts = contracts
            let alreadyAddedContracts = strongSelf.storage.enabledObject.map { $0.contractAddress }
            let deletedContracts = strongSelf.storage.deletedContracts.map { $0.contractAddress }
            let hiddenContracts = strongSelf.storage.hiddenContracts.map { $0.contractAddress }
            let delegateContracts = strongSelf.storage.delegateContracts.map { $0.contractAddress }
            let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
            var contractsPulled = 0
            var hasRefreshedAfterAddingAllContracts = false

            if contractsToAdd.isEmpty { return }

            for eachContract in contractsToAdd {
                strongSelf.addToken(for: eachContract) { _ in
                    contractsPulled += 1
                    if contractsPulled == contractsToAdd.count {
                        hasRefreshedAfterAddingAllContracts = true
                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                    }
                }
            }

            //TODO clean up
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if !hasRefreshedAfterAddingAllContracts {
                    strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                }
            }
        }.asVoid()
    }

    private func autoDetectPartnerTokens() {
        guard !session.config.isAutoFetchingDisabled else { return }
        switch server {
        case .main:
            autoDetectMainnetPartnerTokens()
        case .xDai:
            autoDetectXDaiPartnerTokens()
        case .rinkeby:
            autoDetectRinkebyPartnerTokens()
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
            break
        }
    }

    private func autoDetectMainnetPartnerTokens() {
        autoDetectTokens(withContracts: Constants.partnerContracts)
    }

    private func autoDetectXDaiPartnerTokens() {
        autoDetectTokens(withContracts: Constants.ethDenverXDaiPartnerContracts)
    }

    private func autoDetectRinkebyPartnerTokens() {
        autoDetectTokens(withContracts: Constants.rinkebyPartnerContracts)
    }

    private func autoDetectTokens(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)]) {
        guard !isAutoDetectingTokens else { return }

        let address = keystore.currentWallet.address
        isAutoDetectingTokens = true
        let operation = AutoDetectTokensOperation(forServer: server, coordinator: self, wallet: address, tokens: contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    private func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer, completion: @escaping () -> Void) {
        let address = keystore.currentWallet.address
        let alreadyAddedContracts = storage.enabledObject.map { $0.contractAddress }
        let deletedContracts = storage.deletedContracts.map { $0.contractAddress }
        let hiddenContracts = storage.hiddenContracts.map { $0.contractAddress }
        let contracts = contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts
        var contractsProcessed = 0
        guard !contracts.isEmpty else {
            completion()
            return
        }
        for each in contracts {
            storage.getTokenType(for: each) { tokenType in
                switch tokenType {
                case .erc875:
                    //TODO long and very similar code below. Extract function
                    let balanceCoordinator = GetERC875BalanceCoordinator(forServer: server)
                    balanceCoordinator.getERC875TokenBalance(for: address, contract: each) { [weak self] result in
                        guard let strongSelf = self else {
                            contractsProcessed += 1
                            if contractsProcessed == contracts.count {
                                completion()
                            }
                            return
                        }
                        switch result {
                        case .success(let balance):
                            if !balance.isEmpty {
                                strongSelf.addToken(for: each) { _ in
                                    DispatchQueue.main.async {
                                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                                    }
                                }
                            }
                        case .failure:
                            break
                        }
                        contractsProcessed += 1
                        if contractsProcessed == contracts.count {
                            completion()
                        }
                    }
                case .erc20:
                    let balanceCoordinator = GetERC20BalanceCoordinator(forServer: server)
                    balanceCoordinator.getBalance(for: address, contract: each) { [weak self] result in
                        guard let strongSelf = self else {
                            contractsProcessed += 1
                            if contractsProcessed == contracts.count {
                                completion()
                            }
                            return
                        }
                        switch result {
                        case .success(let balance):
                            if balance > 0 {
                                strongSelf.addToken(for: each) { _ in
                                    DispatchQueue.main.async {
                                        strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
                                    }
                                }
                            }
                        case .failure:
                            break
                        }
                        contractsProcessed += 1
                        if contractsProcessed == contracts.count {
                            completion()
                        }
                    }
                case .erc721:
                    //Handled in TokensDataStore.refreshBalanceForERC721Tokens()
                    break
                case .erc721ForTickets:
                    //Handled in TokensDataStore.refreshBalanceForNonERC721TicketTokens()
                    break
                case .nativeCryptocurrency:
                    break
                }
            }

        }
    }

    private func addToken(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false, completion: @escaping (TokenObject?) -> Void) {
        fetchContractData(for: contract) { [weak self] data in
            guard let strongSelf = self else { return }
            switch data {
            case .name, .symbol, .balance, .decimals:
                break
            case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else { break }
                let token = ERCToken(
                        contract: contract,
                        server: strongSelf.server,
                        name: name,
                        symbol: symbol,
                        decimals: 0,
                        type: tokenType,
                        balance: balance
                )
                let value = strongSelf.storage.addCustom(token: token)
                completion(value)
            case .fungibleTokenComplete(let name, let symbol, let decimals):
                //We re-use the existing balance value to avoid the Wallets tab showing that token (if it already exist) as balance = 0 momentarily
                let value = strongSelf.storage.enabledObject.first(where: { $0.contractAddress == contract })?.value ?? "0"
                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !(value != "0")) else { break }
                let token = TokenObject(
                        contract: contract,
                        server: strongSelf.server,
                        name: name,
                        symbol: symbol,
                        decimals: Int(decimals),
                        value: value,
                        type: .erc20
                )
                let value2 = strongSelf.storage.add(tokens: [token])[0]
                completion(value2)
            case .delegateTokenComplete:
                strongSelf.storage.add(delegateContracts: [DelegateContract(contractAddress: contract, server: strongSelf.server)])
                completion(.none)
            case .failed(let networkReachable):
                if let networkReachable = networkReachable, networkReachable {
                    strongSelf.storage.add(deadContracts: [DeletedContract(contractAddress: contract, server: strongSelf.server)])
                }
                completion(.none)
            }
        }
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedToken(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) {
        delete(hiddenContract: contract)
        addToken(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
        }
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedTokenPromise(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<TokenObject> {
        struct ImportTokenError: Error { }

        return Promise<TokenObject> { seal in
            delete(hiddenContract: contract)
            addToken(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance) { [weak self] tokenObject in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)

                if let tokenObject = tokenObject {
                    seal.fulfill(tokenObject)
                } else {
                    seal.reject(ImportTokenError())
                }
            }
        }
    }

    private func delete(hiddenContract contract: AlphaWallet.Address) {
        guard let hiddenContract = storage.hiddenContracts.first(where: { contract.sameContract(as: $0.contract) }) else { return }
        //TODO we need to make sure it's all uppercase?
        storage.delete(hiddenContracts: [hiddenContract])
    }

    func fetchContractData(for address: AlphaWallet.Address, completion: @escaping (ContractData) -> Void) {
        fetchContractDataFor(address: address, storage: storage, assetDefinitionStore: assetDefinitionStore, completion: completion)
    }

    func showTokenList(for type: PaymentFlow, token: TokenObject, navigationController: UINavigationController) {
        guard !token.nonZeroBalance.isEmpty else {
            navigationController.displayError(error: NoTokenError())
            return
        }

        let tokensCardCoordinator = TokensCardCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                tokensStorage: storage,
                ethPrice: cryptoPrice,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                analyticsCoordinator: analyticsCoordinator
        )
        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()

        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(coordinator: tokensCardCoordinator, token: token)
        case (.send, .watch):
            tokensCardCoordinator.isReadOnly = true
        }
    }

    private func makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(coordinator: TokensCardCoordinator, token: TokenObject) {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            break
        case .erc721:
            //TODO is this check still necessary?
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .backedByOpenSea:
                break
            case .notBackedByOpenSea:
                coordinator.isReadOnly = true
            }
        }
    }

    func show(fungibleToken token: TokenObject, transactionType: TransactionType, navigationController: UINavigationController) {
        let viewController = TokenViewController(session: session, tokensDataStore: storage, assetDefinition: assetDefinitionStore, transactionType: transactionType, analyticsCoordinator: analyticsCoordinator, token: token)
        //TODO fetch and use chart history data: `coinTickersFetcher.fetchChartHistories(addressToRPCServerKey: .init(address: token.contractAddress, server: token.server))`
        viewController.delegate = self
        let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, tokensStore: storage, transactionsStore: transactionsStorage, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider)
        viewController.configure(viewModel: viewModel)

        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: {
            navigationController.popToRootViewController(animated: true)
        })

        navigationController.pushViewController(viewController, animated: true)

        refreshTokenViewControllerUponAssetDefinitionChanges(viewController, forTransactionType: transactionType, transactionsStore: transactionsStorage)
    }

    private func refreshTokenViewControllerUponAssetDefinitionChanges(_ viewController: TokenViewController, forTransactionType transactionType: TransactionType, transactionsStore: TransactionsStorage) {
        assetDefinitionStore.subscribeToBodyChanges { [weak self, weak viewController] contract in
            guard let strongSelf = self, let viewController = viewController else { return }
            guard contract.sameContract(as: transactionType.contract) else { return }
            let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: strongSelf.session, tokensStore: strongSelf.storage, transactionsStore: transactionsStore, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.tokenActionsProvider)
            viewController.configure(viewModel: viewModel)
        }
        assetDefinitionStore.subscribeToSignatureChanges { [weak self, weak viewController] contract in
            guard let strongSelf = self, let viewController = viewController else { return }
            guard contract.sameContract(as: transactionType.contract) else { return }
            let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: strongSelf.session, tokensStore: strongSelf.storage, transactionsStore: transactionsStore, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.tokenActionsProvider)
            viewController.configure(viewModel: viewModel)
        }
    }

    func delete(token: TokenObject) {
        assetDefinitionStore.contractDeleted(token.contractAddress)
        storage.add(hiddenContracts: [HiddenContract(contractAddress: token.contractAddress, server: server)])
        storage.delete(tokens: [token])
        delegate?.tokensDidChange(inCoordinator: self)
    }

    func updateOrderedTokens(with orderedTokens: [TokenObject]) {
        storage.updateOrderedTokens(with: orderedTokens)

        delegate?.tokensDidChange(inCoordinator: self)
    }

    func mark(token: TokenObject, isHidden: Bool) {
        storage.update(token: token, action: .isHidden(isHidden))
    }

    func add(token: ERCToken) -> TokenObject {
        let tokenObject = storage.addCustom(token: token)
        delegate?.tokensDidChange(inCoordinator: self)

        return tokenObject
    }

    class AutoDetectTransactedTokensOperation: Operation {
        weak private var coordinator: SingleChainTokenCoordinator?
        private let wallet: AlphaWallet.Address
        override var isExecuting: Bool {
            return coordinator?.isAutoDetectingTransactedTokens ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }

        init(forServer server: RPCServer, coordinator: SingleChainTokenCoordinator, wallet: AlphaWallet.Address) {
            self.coordinator = coordinator
            self.wallet = wallet
            super.init()
            self.queuePriority = server.networkRequestsQueuePriority
        }

        override func main() {
            guard let strongCoordinator = coordinator else { return }
            let fetchErc20Tokens = strongCoordinator.autoDetectTransactedTokensImpl(wallet: wallet, erc20: true)
            let fetchNonErc20Tokens = strongCoordinator.autoDetectTransactedTokensImpl(wallet: wallet, erc20: false)

            when(resolved: [fetchErc20Tokens, fetchNonErc20Tokens]).done { [weak self] _ in
                guard let strongSelf = self else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")
                strongCoordinator.isAutoDetectingTransactedTokens = false
                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            }.cauterize()
        }
    }

    class AutoDetectTokensOperation: Operation {
        weak private var coordinator: SingleChainTokenCoordinator?
        private let wallet: AlphaWallet.Address
        private let tokens: [(name: String, contract: AlphaWallet.Address)]
        override var isExecuting: Bool {
            return coordinator?.isAutoDetectingTokens ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }
        private let server: RPCServer
        init(forServer server: RPCServer, coordinator: SingleChainTokenCoordinator, wallet: AlphaWallet.Address, tokens: [(name: String, contract: AlphaWallet.Address)]) {
            self.coordinator = coordinator
            self.wallet = wallet
            self.tokens = tokens
            self.server = server
            super.init()
            self.queuePriority = server.networkRequestsQueuePriority
        }

        override func main() {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self, let coordinator = strongSelf.coordinator else { return }

                coordinator.autoDetectTokensImpl(withContracts: strongSelf.tokens, server: strongSelf.server) {
                    strongSelf.willChangeValue(forKey: "isExecuting")
                    strongSelf.willChangeValue(forKey: "isFinished")
                    coordinator.isAutoDetectingTokens = false
                    strongSelf.didChangeValue(forKey: "isExecuting")
                    strongSelf.didChangeValue(forKey: "isFinished")
                }
            }
        }
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, fungibleTokenObject tokenObject: TokenObject, navigationController: UINavigationController) {
        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        let xmlHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
        //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: self.session.server, account: self.session.account)
        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        let tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)
        let vc = TokenInstanceActionViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: tokenObject, tokenHolder: tokenHolder, tokensStorage: storage, assetDefinitionStore: assetDefinitionStore, action: action, session: session, keystore: keystore)
        vc.delegate = self
        vc.configure()
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)
    }
}
// swiftlint:enable type_body_length

extension SingleChainTokenCoordinator: TokensCardCoordinatorDelegate {

    func didCancel(in coordinator: TokensCardCoordinator) {
        coordinator.navigationController.popToRootViewController(animated: true)
        removeCoordinator(coordinator)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCardCoordinator) {
        delegate?.didPostTokenScriptTransaction(transaction, in: self)
    }
}

extension SingleChainTokenCoordinator: TokenViewControllerDelegate {

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, inViewController viewController: TokenViewController) {
        delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.shouldOpen(url: url, shouldSwitchServer: shouldSwitchServer, forTransactionType: transactionType, in: self)
    }

    func didTapSend(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.didPress(for: .send(type: transactionType), inCoordinator: self)
    }

    func didTapReceive(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.didPress(for: .request, inCoordinator: self)
    }

    func didTap(transaction: TransactionInstance, inViewController viewController: TokenViewController) {
        delegate?.didTap(transaction: transaction, inViewController: viewController, in: self)
    }

    func didTap(action: TokenInstanceAction, transactionType: TransactionType, viewController: TokenViewController) {
        guard let navigationController = viewController.navigationController else { return }

        let token: TokenObject
        switch transactionType {
        case .ERC20Token(let erc20Token, _, _):
            token = erc20Token
        case .dapp, .ERC721Token, .ERC875Token, .ERC875TokenOrder, .ERC721ForTicketToken, .tokenScript, .claimPaidErc875MagicLink:
            return
        case .nativeCryptocurrency:
            token = TokensDataStore.etherToken(forServer: server)
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
            return
        }
        switch action.type {
        case .tokenScript:
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
        case .erc20Send, .erc20Receive, .nftRedeem, .nftSell, .nonFungibleTransfer, .swap, .xDaiBridge, .buy:
            //Couldn't have reached here
            break
        }
    }
}

extension SingleChainTokenCoordinator: CanOpenURL {
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

extension SingleChainTokenCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.localizedDescription)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)

            let coordinator = TransactionInProgressCoordinator(presentingViewController: coordinator.presentingViewController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }
}

extension SingleChainTokenCoordinator: TokenInstanceActionViewControllerDelegate {
    func confirmTransactionSelected(in viewController: TokenInstanceActionViewController, tokenObject: TokenObject, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        guard let navigationController = viewController.navigationController else { return }

        switch transactionFunction.makeUnConfirmedTransaction(withTokenObject: tokenObject, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, session: session) {
        case .success((let transaction, let functionCallMetaData)):
            let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: .tokenScriptTransaction(confirmType: .signThenSend, contract: contract, keystore: keystore, functionCallMetaData: functionCallMetaData, ethPrice: cryptoPrice), analyticsCoordinator: analyticsCoordinator)
            coordinator.delegate = self
            addCoordinator(coordinator)
            coordinator.start(fromSource: .tokenScript)
        case .failure:
            //TODO throw an error
            break
        }
    }

    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController) {
        //TODO: do nothing. We can probably even remove show redemption info?
    }

    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController) {
        viewController.navigationController?.popViewController(animated: true)
    }
}

extension SingleChainTokenCoordinator: TransactionInProgressCoordinatorDelegate {

    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)
    }
}

/// Failure to obtain contract data may be due to no-connectivity. So we should check .failed(networkReachable: Bool)
// swiftlint:disable function_body_length
func fetchContractDataFor(address: AlphaWallet.Address, storage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, completion: @escaping (ContractData) -> Void) {
    var completedName: String?
    var completedSymbol: String?
    var completedBalance: [String]?
    var completedDecimals: UInt8?
    var completedTokenType: TokenType?
    var failed = false

    func callCompletionFailed() {
        guard !failed else { return }
        failed = true
        //TODO maybe better to share an instance of the reachability manager
        completion(.failed(networkReachable: NetworkReachabilityManager()?.isReachable))
    }

    func callCompletionAsDelegateTokenOrNot() {
        assert(completedSymbol != nil && completedSymbol?.isEmpty == true)
        //Must check because we also get an empty symbol (and name) if there's no connectivity
        //TODO maybe better to share an instance of the reachability manager
        if let reachabilityManager = NetworkReachabilityManager(), reachabilityManager.isReachable {
            completion(.delegateTokenComplete)
        } else {
            callCompletionFailed()
        }
    }

    func callCompletionOnAllData() {
        if let completedName = completedName, let completedSymbol = completedSymbol, let completedBalance = completedBalance, let tokenType = completedTokenType {
            if completedSymbol.isEmpty {
                callCompletionAsDelegateTokenOrNot()
            } else {
                completion(.nonFungibleTokenComplete(name: completedName, symbol: completedSymbol, balance: completedBalance, tokenType: tokenType))
            }
        } else if let completedName = completedName, let completedSymbol = completedSymbol, let completedDecimals = completedDecimals {
            if completedSymbol.isEmpty {
                callCompletionAsDelegateTokenOrNot()
            } else {
                completion(.fungibleTokenComplete(name: completedName, symbol: completedSymbol, decimals: completedDecimals))
            }
        }
    }

    assetDefinitionStore.fetchXML(forContract: address)

    storage.getContractName(for: address) { result in
        switch result {
        case .success(let name):
            completedName = name
            completion(.name(name))
            callCompletionOnAllData()
        case .failure:
            callCompletionFailed()
        }
    }

    storage.getContractSymbol(for: address) { result in
        switch result {
        case .success(let symbol):
            completedSymbol = symbol
            completion(.symbol(symbol))
            callCompletionOnAllData()
        case .failure:
            callCompletionFailed()
        }
    }

    storage.getTokenType(for: address) { tokenType in
        completedTokenType = tokenType
        switch tokenType {
        case .erc875:
            storage.getERC875Balance(for: address) { result in
                switch result {
                case .success(let balance):
                    completedBalance = balance
                    completion(.balance(balance: balance, tokenType: .erc875))
                    callCompletionOnAllData()
                case .failure:
                    callCompletionFailed()
                }
            }
        case .erc721:
            storage.getERC721Balance(for: address) { result in
                switch result {
                case .success(let balance):
                    completedBalance = balance
                    completion(.balance(balance: balance, tokenType: .erc721))
                    callCompletionOnAllData()
                case .failure:
                    callCompletionFailed()
                }
            }
        case .erc721ForTickets:
            storage.getERC721ForTicketsBalance(for: address) { result in
                switch result {
                case .success(let balance):
                    completedBalance = balance
                    completion(.balance(balance: balance, tokenType: .erc721ForTickets))
                    callCompletionOnAllData()
                case .failure:
                    callCompletionFailed()
                }
            }
        case .erc20:
            storage.getDecimals(for: address) { result in
                switch result {
                case .success(let decimal):
                    completedDecimals = decimal
                    completion(.decimals(decimal))
                    callCompletionOnAllData()
                case .failure:
                    callCompletionFailed()
                }
            }
        case .nativeCryptocurrency:
            break
        }
    }
}
// swiftlint:enable function_body_length
