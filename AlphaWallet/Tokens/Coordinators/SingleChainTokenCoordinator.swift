// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import RealmSwift
import PromiseKit
import Result

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

protocol SingleChainTokenCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func tokensDidChange(inCoordinator coordinator: SingleChainTokenCoordinator)
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: SingleChainTokenCoordinator)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: SingleChainTokenCoordinator)
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator)
    func didTapAddAlert(for tokenObject: TokenObject, in cordinator: SingleChainTokenCoordinator)
    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in cordinator: SingleChainTokenCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: SingleChainTokenCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

// swiftlint:disable type_body_length
class SingleChainTokenCoordinator: Coordinator {
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let ethPrice: Subscribable<Double>
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
    private let activitiesService: ActivitiesServiceType
    let session: WalletSession
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    private lazy var tokenProvider: TokenProviderType = TokenProvider(account: storage.account, server: storage.server)

    var server: RPCServer {
        session.server
    }
    private let queue = DispatchQueue(label: "com.SingleChainTokenCoordinator.updateQueue")
    private let alertService: PriceAlertServiceType
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
            coinTickersFetcher: CoinTickersFetcherType,
            activitiesService: ActivitiesServiceType,
            alertService: PriceAlertServiceType
    ) {
        self.session = session
        self.keystore = keystore
        self.storage = tokensStorage
        self.ethPrice = ethPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
        self.tokenActionsProvider = tokenActionsProvider
        self.transactionsStorage = transactionsStorage
        self.coinTickersFetcher = coinTickersFetcher
        self.activitiesService = activitiesService
        self.alertService = alertService
    }

    func start() {
        //Since this is called at launch, we don't want it to block launching
        queue.async { [weak self] in
            self?.autoDetectTransactedTokens()
            self?.autoDetectPartnerTokens()
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

    private func contractsForTransactedTokens(detectedContracts: [AlphaWallet.Address], storage: TokensDataStore) -> Promise<[AlphaWallet.Address]> {
        return Promise { seal in
            DispatchQueue.main.async {
                let alreadyAddedContracts = storage.enabledObjectAddresses
                let deletedContracts = storage.deletedContracts.map { $0.contractAddress }
                let hiddenContracts = storage.hiddenContracts.map { $0.contractAddress }
                let delegateContracts = storage.delegateContracts.map { $0.contractAddress }
                let contractsToAdd = detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts

                seal.fulfill(contractsToAdd)
            }
        }
    }

    private func autoDetectTransactedTokensImpl(wallet: AlphaWallet.Address, erc20: Bool) -> Promise<Void> {
        let startBlock: Int?
        if erc20 {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        } else {
            startBlock = Config.getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        }

        return firstly {
            GetContractInteractions(queue: queue).getContractList(address: wallet, server: server, startBlock: startBlock, erc20: erc20)
        }.then(on: queue) { [weak self] contracts, maxBlockNumber -> Promise<Bool> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            if let maxBlockNumber = maxBlockNumber {
                if erc20 {
                    Config.setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                } else {
                    Config.setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(maxBlockNumber, server: strongSelf.server, wallet: wallet)
                }
            }
            let currentAddress = strongSelf.keystore.currentWallet.address
            guard currentAddress.sameContract(as: wallet) else { return .init(error: PMKError.cancelled) }
            let detectedContracts = contracts

            return strongSelf.contractsForTransactedTokens(detectedContracts: detectedContracts, storage: strongSelf.storage).then(on: strongSelf.queue, { contractsToAdd -> Promise<Bool> in
                let promises = contractsToAdd.compactMap { each -> Promise<BatchObject> in
                    strongSelf.fetchBatchObjectFromContractData(for: each, server: strongSelf.server, storage: strongSelf.storage)
                }

                return when(resolved: promises).then(on: .main, { values -> Promise<Bool> in
                    let values = values.compactMap { $0.optionalValue }.filter { $0.nonEmptyAction }
                    strongSelf.storage.addBatchObjects(values: values)

                    return .value(!values.isEmpty)
                })
            })
        }.get(on: .main, { [weak self] didUpdateObjects in
            guard let strongSelf = self else { return }

            if didUpdateObjects {
                strongSelf.notifyTokensDidChange()
            }
        }).asVoid()
    }

    private func notifyTokensDidChange() {
        //NOTE: as UI is going to get updated from realm notification not sure if we still need it here
        // delegate?.tokensDidChange(inCoordinator: self)
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
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
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

    private func contractsToAutodetectTokens(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], storage: TokensDataStore) -> Promise<[AlphaWallet.Address]> {
        return Promise { seal in
            DispatchQueue.main.async {
                let alreadyAddedContracts = storage.enabledObjectAddresses
                let deletedContracts = storage.deletedContracts.map { $0.contractAddress }
                let hiddenContracts = storage.hiddenContracts.map { $0.contractAddress }

                seal.fulfill(contractsToDetect.map { $0.contract } - alreadyAddedContracts - deletedContracts - hiddenContracts)
            }
        }
    }

    private func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<Void> {
        let address = keystore.currentWallet.address
        return contractsToAutodetectTokens(withContracts: contractsToDetect, storage: storage).map(on: queue, { contracts -> [Promise<SingleChainTokenCoordinator.BatchObject>] in
            contracts.map { [weak self] each -> Promise<BatchObject> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                return strongSelf.tokenProvider.getTokenType(for: each).then { tokenType -> Promise<BatchObject> in
                    switch tokenType {
                    case .erc875:
                        //TODO long and very similar code below. Extract function
                        let balanceCoordinator = GetERC875BalanceCoordinator(forServer: server)
                        return balanceCoordinator.getERC875TokenBalance(for: address, contract: each).then { balance -> Promise<BatchObject> in
                            if balance.isEmpty {
                                return .value(.none)
                            } else {
                                return strongSelf.fetchBatchObjectFromContractData(for: each, server: server, storage: strongSelf.storage)
                            }
                        }.recover { _ -> Guarantee<BatchObject> in
                            return .value(.none)
                        }
                    case .erc20:
                        let balanceCoordinator = GetERC20BalanceCoordinator(forServer: server)
                        return balanceCoordinator.getBalance(for: address, contract: each).then { balance -> Promise<BatchObject> in
                            if balance > 0 {
                                return strongSelf.fetchBatchObjectFromContractData(for: each, server: server, storage: strongSelf.storage)
                            } else {
                                return .value(.none)
                            }
                        }.recover { _ -> Guarantee<BatchObject> in
                            return .value(.none)
                        }
                    case .erc721, .erc721ForTickets, .erc1155, .nativeCryptocurrency:
                        //Handled in PrivateBalanceFetcher.refreshBalanceForErc721Or1155Tokens()
                        return .value(.none)
                    }
                }
            }
        }).then(on: queue, { promises -> Promise<Bool> in
            return when(resolved: promises).then(on: .main, { [weak self] results -> Promise<Bool> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                let values = results.compactMap { $0.optionalValue }.filter { $0.nonEmptyAction }

                strongSelf.storage.addBatchObjects(values: values)

                return .value(!values.isEmpty)
            })
        }).get(on: .main, { [weak self] didUpdate in
            guard let strongSelf = self else { return }

            if didUpdate {
                strongSelf.notifyTokensDidChange()
            }
        }).asVoid()
    }

    enum BatchObject {
        case ercToken(ERCToken)
        case tokenObject(TokenObject)
        case delegateContracts([DelegateContract])
        case deletedContracts([DeletedContract])
        case none

        var nonEmptyAction: Bool {
            switch self {
            case .none:
                return false
            case .ercToken, .tokenObject, .delegateContracts, .deletedContracts:
                return true
            }
        }
    }

    private func fetchBatchObjectFromContractData(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false, server: RPCServer, storage: TokensDataStore) -> Promise <BatchObject> {
        return Promise { seal in
            fetchContractData(for: contract) { data in
                DispatchQueue.main.async {
                    switch data {
                    case .name, .symbol, .balance, .decimals:
                        break
                    case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                        guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else { break }
                        let token = ERCToken(
                                contract: contract,
                                server: server,
                                name: name,
                                symbol: symbol,
                                decimals: 0,
                                type: tokenType,
                                balance: balance
                        )

                        seal.fulfill(.ercToken(token))
                    case .fungibleTokenComplete(let name, let symbol, let decimals):
                        //We re-use the existing balance value to avoid the Wallets tab showing that token (if it already exist) as balance = 0 momentarily
                        storage.tokenPromise(forContract: contract).done { tokenObject in
                            let value = tokenObject?.value ?? "0"
                            guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !(value != "0")) else { return seal.fulfill(.none) }
                            let token = TokenObject(
                                    contract: contract,
                                    server: server,
                                    name: name,
                                    symbol: symbol,
                                    decimals: Int(decimals),
                                    value: value,
                                    type: .erc20
                            )
                            seal.fulfill(.tokenObject(token))
                        }.cauterize()
                    case .delegateTokenComplete:
                        seal.fulfill(.delegateContracts([DelegateContract(contractAddress: contract, server: server)]))
                    case .failed(let networkReachable):
                        if let networkReachable = networkReachable, networkReachable {
                            seal.fulfill(.deletedContracts([DeletedContract(contractAddress: contract, server: server)]))
                        } else {
                            seal.fulfill(.none)
                        }
                    }
                }
            }
        }
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedToken(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) {
        firstly {
            addImportedTokenPromise(forContract: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }.done { _ in
            // no-op
        }.cauterize()
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedTokenPromise(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<TokenObject> {
        struct ImportTokenError: Error { }

        return firstly {
            delete(hiddenContract: contract)
        }.then(on: .main, { [weak self] _ -> Promise<TokenObject> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            return firstly {
                strongSelf.fetchBatchObjectFromContractData(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance, server: strongSelf.server, storage: strongSelf.storage)
            }.map(on: .main, { operation -> [TokenObject] in
                return strongSelf.storage.addBatchObjects(values: [operation])
            }).map(on: .main, { tokenObjects -> TokenObject in
                if let tokenObject = tokenObjects.first {
                    return tokenObject
                } else {
                    throw ImportTokenError()
                }
            })
        }).get(on: .main, { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.notifyTokensDidChange()
        })
    }

    private func delete(hiddenContract contract: AlphaWallet.Address) -> Promise<Void> {
        return Promise<Void> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                if let hiddenContract = strongSelf.storage.hiddenContracts.first(where: { contract.sameContract(as: $0.contract) }) {
                    //TODO we need to make sure it's all uppercase?
                    strongSelf.storage.delete(hiddenContracts: [hiddenContract])
                } else {
                    //no-op
                }

                seal.fulfill(())
            }
        }
    }

    func fetchContractData(for address: AlphaWallet.Address, completion: @escaping (ContractData) -> Void) {
        ContractDataDetector(address: address, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore).fetch(completion: completion)
    }

    func showTokenList(for type: PaymentFlow, token: TokenObject, navigationController: UINavigationController) {
        guard !token.nonZeroBalance.isEmpty else {
            navigationController.displayError(error: NoTokenError())
            return
        }

        switch token.type {
        case .erc1155:
            showTokensCardCollection(for: type, token: token, navigationController: navigationController)
        case .erc721, .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            showTokenCard(for: type, token: token, navigationController: navigationController)
        }
    }

    private func showTokensCardCollection(for type: PaymentFlow, token: TokenObject, navigationController: UINavigationController) {
        let tokensCardCoordinator = TokensCardCollectionCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                tokensStorage: storage,
                ethPrice: ethPrice,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                analyticsCoordinator: analyticsCoordinator,
                activitiesService: activitiesService,
                transactionsStorage: transactionsStorage,
                paymantFlow: type
        )

        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()
    }

    private func showTokenCard(for type: PaymentFlow, token: TokenObject, navigationController: UINavigationController) {
        let tokensCardCoordinator = TokensCardCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                tokensStorage: storage,
                ethPrice: ethPrice,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                analyticsCoordinator: analyticsCoordinator
        )

        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()
        tokensCardCoordinator.makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(type: type)
    }

    private func transactionsFilter(for strategy: ActivitiesFilterStrategy, tokenObject: TokenObject) -> TransactionsFilterStrategy {
        let filter = FilterInSingleTransactionsStorage(transactionsStorage: transactionsStorage) { tx in
            return strategy.isRecentTransaction(transaction: tx)
        }

        return .filter(filter: filter, tokenObject: tokenObject)
    }

    func show(fungibleToken token: TokenObject, transactionType: TransactionType, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilter(for: activitiesFilterStrategy, tokenObject: transactionType.tokenObject))
        let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider)
        let viewController = TokenViewController(session: session, assetDefinition: assetDefinitionStore, transactionType: transactionType, analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, activitiesService: activitiesService, alertService: alertService)
        viewController.delegate = self

        //NOTE: refactor later with subscribable coin ticker, and chart history
        coinTickersFetcher.fetchChartHistories(addressToRPCServerKey: token.addressAndRPCServer, force: false, periods: ChartHistoryPeriod.allCases).done { [weak self, weak viewController] history in
            guard let strongSelf = self, let viewController = viewController else { return }

            var viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.tokenActionsProvider)
            viewModel.chartHistory = history
            viewController.configure(viewModel: viewModel)
        }.catch { _ in
            //no-op
        }

        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: {
            navigationController.popToRootViewController(animated: true)
        })

        navigationController.pushViewController(viewController, animated: true)
    }

    func delete(token: TokenObject) {
        assetDefinitionStore.contractDeleted(token.contractAddress)
        storage.add(hiddenContracts: [HiddenContract(contractAddress: token.contractAddress, server: server)])
        storage.delete(tokens: [token])

        notifyTokensDidChange()
    }

    func updateOrderedTokens(with orderedTokens: [TokenObject]) {
        storage.updateOrderedTokens(with: orderedTokens)

        notifyTokensDidChange()
    }

    func mark(token: TokenObject, isHidden: Bool) {
        storage.update(token: token, action: .isHidden(isHidden))
    }

    func add(token: ERCToken) -> TokenObject {
        let tokenObject = storage.addCustom(token: token, shouldUpdateBalance: true)
        notifyTokensDidChange()

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
            guard let strongCoordinator = coordinator else { return }

            strongCoordinator.autoDetectTokensImpl(withContracts: tokens, server: server).done { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")
                strongCoordinator.isAutoDetectingTokens = false
                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            }.cauterize()
        }
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, fungibleTokenObject tokenObject: TokenObject, navigationController: UINavigationController) {
        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        let xmlHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
        //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: server, account: session.account)
        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        let tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)

        delegate?.didPress(for: .send(type: .tokenScript(action: action, tokenObject: tokenObject, tokenHolder: tokenHolder)), inViewController: navigationController, in: self)
    }
}
// swiftlint:enable type_body_length

extension SingleChainTokenCoordinator: TokensCardCoordinatorDelegate {
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: TokensCardCoordinator) {
        delegate?.didPress(for: type, inViewController: viewController, in: self)
    }

    func didCancel(in coordinator: TokensCardCoordinator) {
        coordinator.navigationController.popToRootViewController(animated: true)
        removeCoordinator(coordinator)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCardCoordinator) {
        delegate?.didPostTokenScriptTransaction(transaction, in: self)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokensCardCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }
}

extension SingleChainTokenCoordinator: TokenViewControllerDelegate {

    func didTapAddAlert(for tokenObject: TokenObject, in viewController: TokenViewController) {
        delegate?.didTapAddAlert(for: tokenObject, in: self)
    }

    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in viewController: TokenViewController) {
        delegate?.didTapEditAlert(for: tokenObject, alert: alert, in: self)
    }

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, inViewController viewController: TokenViewController) {
        delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.shouldOpen(url: url, shouldSwitchServer: shouldSwitchServer, forTransactionType: transactionType, in: self)
    }

    func didTapSend(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.didPress(for: .send(type: .transaction(transactionType)), inViewController: viewController, in: self)
    }

    func didTapReceive(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController) {
        delegate?.didPress(for: .request, inViewController: viewController, in: self)
    }

    func didTap(activity: Activity, inViewController viewController: TokenViewController) {
        delegate?.didTap(activity: activity, inViewController: viewController, in: self)
    }

    func didTap(transaction: TransactionInstance, inViewController viewController: TokenViewController) {
        delegate?.didTap(transaction: transaction, inViewController: viewController, in: self)
    }

    func didTap(action: TokenInstanceAction, transactionType: TransactionType, viewController: TokenViewController) {
        guard let navigationController = viewController.navigationController else { return }

        let token: TokenObject
        switch transactionType {
        case .erc20Token(let erc20Token, _, _):
            token = erc20Token
        case .dapp, .erc721Token, .erc875Token, .erc875TokenOrder, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink:
            return
        case .nativeCryptocurrency:
            token = TokensDataStore.etherToken(forServer: server)
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
            return
        }
        switch action.type {
        case .tokenScript:
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
        case .erc20Send, .erc20Receive, .nftRedeem, .nftSell, .nonFungibleTransfer, .swap, .buy, .bridge:
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

extension SingleChainTokenCoordinator: TokensCardCollectionCoordinatorDelegate {

    func didTap(for type: PaymentFlow, in coordinator: TokensCardCollectionCoordinator, viewController: UIViewController) {
        delegate?.didPress(for: type, inViewController: viewController, in: self)
    }

    func didClose(in coordinator: TokensCardCollectionCoordinator) {
        removeCoordinator(coordinator)
    }

    func didTap(transaction: TransactionInstance, in coordinator: TokensCardCollectionCoordinator) {
        delegate?.didTap(transaction: transaction, inViewController: coordinator.rootViewController, in: self)
    }

    func didTap(activity: Activity, in coordinator: TokensCardCollectionCoordinator) {
        delegate?.didTap(activity: activity, inViewController: coordinator.rootViewController, in: self)
    }
}
