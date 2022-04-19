// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Result

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

protocol SingleChainTokenCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: SingleChainTokenCoordinator)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: SingleChainTokenCoordinator)
    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator)
    func didTapAddAlert(for tokenObject: TokenObject, in coordinator: SingleChainTokenCoordinator)
    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in coordinator: SingleChainTokenCoordinator)
}

class SingleChainTokenCoordinator: Coordinator {
    private let keystore: Keystore
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenActionsProvider: TokenActionsProvider
    private let coinTickersFetcher: CoinTickersFetcherType
    private let activitiesService: ActivitiesServiceType
    let session: WalletSession
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var server: RPCServer {
        session.server
    }
    private let alertService: PriceAlertServiceType
    private let tokensAutodetector: TokensAutodetector
    private lazy var tokenObjectFetcher: TokenObjectFetcher = {
        SingleChainTokenObjectFetcher(account: session.account, server: server, assetDefinitionStore: assetDefinitionStore)
    }()

    init(
            session: WalletSession,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: NonActivityEventsDataStore,
            analyticsCoordinator: AnalyticsCoordinator,
            tokenActionsProvider: TokenActionsProvider,
            coinTickersFetcher: CoinTickersFetcherType,
            activitiesService: ActivitiesServiceType,
            alertService: PriceAlertServiceType,
            tokensAutodetector: TokensAutodetector
    ) {
        self.session = session
        self.keystore = keystore
        self.tokensDataStore = tokensStorage
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.tokensAutodetector = tokensAutodetector
    }

    func start() {
        tokensAutodetector.start()
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func addImportedToken(forContract contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<TokenObject> {
        struct ImportTokenError: Error { }

        return firstly {
            tokenObjectFetcher.fetchTokenObject(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }.map { operation -> TokenObject in
            if let tokenObject = self.tokensDataStore.addTokenObjects(values: [operation]).first {
                return tokenObject
            } else {
                throw ImportTokenError()
            }
        }
    }

    func fetchContractData(for address: AlphaWallet.Address, completion: @escaping (ContractData) -> Void) {
        ContractDataDetector(address: address, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore)
            .fetch(completion: completion)
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
        guard let transactionType = type.transactionType else { return }

        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, tokenObject: transactionType.tokenObject))

        let tokensCardCoordinator = TokensCardCollectionCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                tokensStorage: tokensDataStore,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                analyticsCoordinator: analyticsCoordinator,
                activitiesService: activitiesService,
                paymantFlow: type
        )

        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()
    }

    private func showTokenCard(for type: PaymentFlow, token: TokenObject, navigationController: UINavigationController) {
        guard let transactionType = type.transactionType else { return }

        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, tokenObject: transactionType.tokenObject))

        let tokensCardCoordinator = TokensCardCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                tokensStorage: tokensDataStore,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                analyticsCoordinator: analyticsCoordinator,
                activitiesService: activitiesService
        )

        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()
    }

    func show(fungibleToken token: TokenObject, transactionType: TransactionType, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, tokenObject: transactionType.tokenObject))
        let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: session, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider)
        let viewController = TokenViewController(keystore: keystore, session: session, assetDefinition: assetDefinitionStore, transactionType: transactionType, analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, activitiesService: activitiesService, alertService: alertService)
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

        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(selectionClosure: { _ in
            navigationController.popToRootViewController(animated: true)
        })

        navigationController.pushViewController(viewController, animated: true)
    }

    func updateOrderedTokens(with orderedTokens: [TokenObject]) {
        tokensDataStore.updateOrderedTokens(with: orderedTokens)
    }

    func mark(token: TokenObject, isHidden: Bool) {
        guard !token.isInvalidated else { return }
        tokensDataStore.updateToken(primaryKey: token.primaryKey, action: .isHidden(isHidden))
    }

    func add(token: ERCToken) -> TokenObject {
        let tokenObject = tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: true)

        return tokenObject[0]
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

extension SingleChainTokenCoordinator: TokensCardCoordinatorDelegate {
    func didTap(transaction: TransactionInstance, in coordinator: TokensCardCoordinator) {
        delegate?.didTap(transaction: transaction, inViewController: coordinator.rootViewController, in: self)
    }

    func didTap(activity: Activity, in coordinator: TokensCardCoordinator) {
        delegate?.didTap(activity: activity, inViewController: coordinator.rootViewController, in: self)
    }

    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: TokensCardCoordinator) {
        delegate?.didPress(for: type, inViewController: viewController, in: self)
    }

    func didCancel(in coordinator: TokensCardCoordinator) {
        removeCoordinator(coordinator)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCardCoordinator) {
        delegate?.didPostTokenScriptTransaction(transaction, in: self)
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
        case .dapp, .erc721Token, .erc875Token, .erc875TokenOrder, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return
        case .nativeCryptocurrency:
            token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
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
