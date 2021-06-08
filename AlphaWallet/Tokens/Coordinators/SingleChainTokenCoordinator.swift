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
    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator)
}

// swiftlint:disable type_body_length
class SingleChainTokenCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let storage: TokensDataStore
    private let cryptoPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let analyticsCoordinator: AnalyticsCoordinator
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let tokenActionsProvider: TokenActionsProvider
    private let transactionsStorage: TransactionsStorage
    private let coinTickersFetcher: CoinTickersFetcherType
    private let activitiesService: ActivitiesServiceType
    private let session: WalletSession
    private let sessions: ServerDictionary<WalletSession>
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var server: RPCServer {
        session.server
    }
    private let autoDetectTokensProvider: AutodetectTokensProviderType
    private let tokenProvider: TokenProviderType

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
            sessions: ServerDictionary<WalletSession>
    ) {
        self.sessions = sessions
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
        self.activitiesService = activitiesService

        self.tokenProvider = TokenProvider(storage: storage, assetDefinitionStore: assetDefinitionStore)
        self.autoDetectTokensProvider = AutodetectTokensProvider(keystore: keystore, storage: storage, assetDefinitionStore: assetDefinitionStore, tokenProvider: tokenProvider)
        super.init()
        autoDetectTokensProvider.delegate = self
    }

    func start() {
        //Since this is called at launch, we don't want it to block launching
        DispatchQueue.global().async { [weak self] in
            self?.autoDetectTransactedTokens()
            self?.autoDetectPartnerTokens()
        }
    }

    func isServer(_ server: RPCServer) -> Bool {
        return self.server == server
    }

    ///Implementation: We refresh once only, after all the auto detected tokens' data have been pulled because each refresh pulls every tokens' (including those that already exist before the this auto detection) price as well as balance, placing heavy and redundant load on the device. After a timeout, we refresh once just in case it took too long, so user at least gets the chance to see some auto detected tokens
    private func autoDetectTransactedTokens() {
        //TODO we don't auto detect tokens if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
        guard !isRunningTests() else { return }
        guard !session.config.isAutoFetchingDisabled else { return }
        guard !autoDetectTokensProvider.isAutoDetectingTransactedTokens else { return }

        autoDetectTokensProvider.isAutoDetectingTransactedTokens = true
        let operation = autoDetectTokensProvider.autoDetectTransactedTokensOperation(forServer: server, wallet: keystore.currentWallet.address)
        autoDetectTransactedTokensQueue.addOperation(operation)
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
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .custom, .heco_testnet, .heco, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet:
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
        guard !autoDetectTokensProvider.isAutoDetectingTokens else { return }

        let address = keystore.currentWallet.address
        autoDetectTokensProvider.isAutoDetectingTokens = true
        let operation = autoDetectTokensProvider.autoDetectTokensOperation(forServer: server, wallet: address, tokens: contractsToDetect)
        autoDetectTokensQueue.addOperation(operation)
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedToken(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) {
        tokenProvider.addToken(for: contract, server: server) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)
        }
    }

    func addImportedTokenPromise(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<TokenObject> {
        struct ImportTokenError: Error { }
        return tokenProvider.addImportedTokenPromise(forContract: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance)
            .then { [weak self]  token -> Promise<TokenObject> in
                guard let strongSelf = self else { return .init(error: ImportTokenError()) }
                strongSelf.delegate?.tokensDidChange(inCoordinator: strongSelf)

                return .value(token)
            }
    }

    func fetchContractData(for address: AlphaWallet.Address, completion: @escaping (ContractData) -> Void) {
        tokenProvider.fetchContractData(for: address, completion: completion)
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

    private func transactionsFilter(for strategy: ActivitiesFilterStrategy, transactionType: TransactionType) -> TransactionsFilterStrategy {
        let filter = FilterInSingleTransactionsStorage(transactionsStorage: transactionsStorage) { tx in
            return strategy.isRecentTransaction(transaction: tx)
        }
        
        return .filter(filter: filter)
    }

    func show(fungibleToken token: TokenObject, transactionType: TransactionType, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilter(for: activitiesFilterStrategy, transactionType: transactionType))
        let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, tokensStore: storage, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider)
        let viewController = TokenViewController(session: session, tokensDataStore: storage, assetDefinition: assetDefinitionStore, transactionType: transactionType, analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, activitiesService: activitiesService, sessions: sessions)
        
        viewController.delegate = self

        //NOTE: refactor later with subscribable coin tiker, and chart history
        coinTickersFetcher.fetchChartHistories(addressToRPCServerKey: token.addressAndRPCServer, force: false, periods: ChartHistoryPeriod.allCases).done { [weak self, weak viewController, weak session] history in
            guard let strongSelf = self, let viewController = viewController, let session = session else { return }

            var viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, tokensStore: strongSelf.storage, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.tokenActionsProvider)
            viewModel.chartHistory = history
            viewController.configure(viewModel: viewModel)
        }.catch { _ in
            //no-op
        }
        
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: {
            navigationController.popToRootViewController(animated: true)
        })

        navigationController.pushViewController(viewController, animated: true)

        refreshTokenViewControllerUponAssetDefinitionChanges(viewController, transactionType: transactionType)
    }

    private func refreshTokenViewControllerUponAssetDefinitionChanges(_ viewController: TokenViewController, transactionType: TransactionType) {
        assetDefinitionStore.subscribeToBodyChanges { [weak self, weak viewController] contract in
            guard let strongSelf = self, let viewController = viewController else { return }
            guard contract.sameContract(as: transactionType.contract) else { return }

            strongSelf.reloadTokenViewModel(forTransactionType: transactionType, viewController: viewController)
        }
        
        assetDefinitionStore.subscribeToSignatureChanges { [weak self, weak viewController] contract in
            guard let strongSelf = self, let viewController = viewController else { return }
            guard contract.sameContract(as: transactionType.contract) else { return }

            strongSelf.reloadTokenViewModel(forTransactionType: transactionType, viewController: viewController)
        }
    }

    private func reloadTokenViewModel(forTransactionType transactionType: TransactionType, viewController: TokenViewController) {
        let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, tokensStore: storage, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider)
        viewController.configure(viewModel: viewModel)
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

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, fungibleTokenObject tokenObject: TokenObject, navigationController: UINavigationController) {
        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        let xmlHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
        //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: server, account: session.account)
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
extension SingleChainTokenCoordinator: AutodetectTokensProviderDelegate {
    func tokensDidChange(inCoordinator coordinator: AutodetectTokensProvider) {
        delegate?.tokensDidChange(inCoordinator: self)
    }
}

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

        switch transactionFunction.makeUnConfirmedTransaction(withTokenObject: tokenObject, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, account: session.account) {
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
