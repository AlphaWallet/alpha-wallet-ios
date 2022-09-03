// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Combine
import AlphaWalletFoundation

struct FungibleTokenViewModelInput {
    let appear: AnyPublisher<Void, Never>
}

struct FungibleTokenViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenViewModel.ViewState, Never>
    let activities: AnyPublisher<ActivityPageViewModel, Never>
    let alerts: AnyPublisher<PriceAlertsPageViewModel, Never>
}

final class FungibleTokenViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let coinTickersFetcher: CoinTickersFetcher
    private var validatedToken: Token? {
        switch transactionType {
        case .nativeCryptocurrency:
            //TODO might as well just make .nativeCryptocurrency hold the TokenObject instance too
            return MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)
        case .erc20Token(let token, _, _):
            return token
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private let tokensService: TokenViewModelState & TokenBalanceRefreshable
    private let activitiesService: ActivitiesServiceType
    private let alertService: PriceAlertServiceType
    private lazy var tokenHolder: TokenHolder? = {
        return validatedToken.flatMap { $0.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account) }
    }()

    let transactionType: TransactionType
    let session: WalletSession
    let assetDefinitionStore: AssetDefinitionStore
    var wallet: Wallet { session.account }

    lazy var tokenScriptFileStatusHandler = XMLHandler(token: transactionType.tokenObject, assetDefinitionStore: assetDefinitionStore)

    var token: Token {
        return transactionType.tokenObject
    }

    private (set) var actions: [TokenInstanceAction] = []

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        if let token = validatedToken {
            let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
            return xmlHandler.tokenScriptStatus
        } else {
            assertImpossibleCodePath()
            return .value(.type2BadTokenScript(isDebugMode: false, error: .custom("Unknown"), reason: nil))
        }
    }

    private var fungibleBalance: BigInt? {
        switch transactionType {
        case .nativeCryptocurrency:
            let token: Token = MultipleChainsTokensDataStore.functional.token(forServer: transactionType.server)
            return tokensService.tokenViewModel(for: token)?.balance.value
        case .erc20Token(let token, _, _):
            return tokensService.tokenViewModel(for: token)?.balance.value
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }

    var hasCoinTicker: Bool {
        switch transactionType {
        case .nativeCryptocurrency:
            let token: Token = MultipleChainsTokensDataStore.functional.token(forServer: transactionType.server)
            return tokensService.tokenViewModel(for: token)?.balance.ticker != nil
        case .erc20Token(let token, _, _):
            return tokensService.tokenViewModel(for: token)?.balance.ticker != nil
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return false
        }
    }

    lazy var tokenInfoPageViewModel = TokenInfoPageViewModel(transactionType: transactionType, coinTickersFetcher: coinTickersFetcher, service: tokensService)

    var destinationAddress: AlphaWallet.Address {
        return transactionType.contract
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var sendButtonTitle: String {
        return R.string.localizable.send()
    }

    var receiveButtonTitle: String {
        return R.string.localizable.receive()
    }

    init(activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType, transactionType: TransactionType, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, coinTickersFetcher: CoinTickersFetcher, tokensService: TokenViewModelState & TokenBalanceRefreshable) {
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.transactionType = transactionType
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
        self.tokensService = tokensService
    } 

    func tokenScriptWarningMessage(for action: TokenInstanceAction) -> TokenScriptWarningMessage? {
        if let tokenHolder = tokenHolder, let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
            if let denialMessage = selection.denial {
                return .warning(string: denialMessage)
            } else {
                //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                return .undefined
            }
        } else {
            return nil
        }
    }

    func buttonState(for action: TokenInstanceAction) -> ActionButtonState {
        func _configButton(action: TokenInstanceAction) -> ActionButtonState {
            if let tokenHolder = tokenHolder, let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
                if selection.denial == nil {
                    return .isDisplayed(false)
                }
            }
            return .noOption
        }

        switch wallet.type {
        case .real:
            return _configButton(action: action)
        case .watch:
            if session.config.development.shouldPretendIsRealWallet {
                return _configButton(action: action)
            } else {
                return .isEnabled(false)
            }
        }
    }

    func transform(input: FungibleTokenViewModelInput) -> FungibleTokenViewModelOutput {
        let whenTokenHolderHasChanged: AnyPublisher<TokenViewModel?, Never> = (tokenHolder?.objectWillChange.eraseToAnyPublisher() ?? .empty())
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenTokenActionsHasChanged = tokenActionsProvider.objectWillChange
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let tokenViewModel = tokensService.tokenViewModelPublisher(for: token).eraseToAnyPublisher()

        let actions = Publishers.MergeMany(tokenViewModel, whenTokenHolderHasChanged, whenTokenActionsHasChanged)
            .compactMap { [weak self] _ in self?.buildTokenActions() }
            .handleEvents(receiveOutput: { [weak self] in self?.actions = $0 })

        let navigationTitle = tokenViewModel.compactMap { $0?.tokenScriptOverrides?.titleInPluralForm }

        input.appear.receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshBalance()
            }.store(in: &cancelable)

        activitiesService.start()

        let activities = activitiesService.activitiesPublisher
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .receive(on: RunLoop.main)

        let alerts = alertService.alertsPublisher(forStrategy: .token(token))
            .map { PriceAlertsPageViewModel(alerts: $0) }
            .receive(on: RunLoop.main)

        let viewState = Publishers.CombineLatest(actions, navigationTitle)
            .map { actions, navigationTitle in FungibleTokenViewModel.ViewState(navigationTitle: navigationTitle, actions: actions) }

        return .init(viewState: viewState.eraseToAnyPublisher(),
                    activities: activities.eraseToAnyPublisher(),
                    alerts: alerts.eraseToAnyPublisher())
    }

    private func buildTokenActions() -> [TokenInstanceAction] {
        guard let token = validatedToken else { return [] }
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.name))")
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875:
                return []
            case .erc721:
                return []
            case .erc721ForTickets:
                return []
            case .erc1155:
                return []
            case .erc20:
                let actions: [TokenInstanceAction] = [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]

                return actions + tokenActionsProvider.actions(token: token)
            case .nativeCryptocurrency:
                let actions: [TokenInstanceAction] = [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]
                switch token.server {
                case .xDai:
                    return [.init(type: .erc20Send), .init(type: .erc20Receive)] + tokenActionsProvider.actions(token: token)
                case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet, .candle:
                    return actions + tokenActionsProvider.actions(token: token)
                }
            }
        } else {
            switch token.type {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                return actionsFromTokenScript
            case .erc20:
                return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
            case .nativeCryptocurrency:
                //TODO we should support retrieval of XML (and XMLHandler) based on address + server. For now, this is only important for native cryptocurrency. So might be ok to check like this for now
                if let server = xmlHandler.server, server.matches(server: token.server) {
                    return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
                } else {
                    //TODO .erc20Send and .erc20Receive names aren't appropriate
                    let actions: [TokenInstanceAction] = [
                        .init(type: .erc20Send),
                        .init(type: .erc20Receive)
                    ]

                    return actions + tokenActionsProvider.actions(token: token)
                }
            }
        }
    }

    private func refreshBalance() {
        switch transactionType {
        case .nativeCryptocurrency:
            tokensService.refreshBalance(updatePolicy: .eth)
        case .erc20Token(let token, _, _):
            tokensService.refreshBalance(updatePolicy: .token(token: token))
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }
    }

    func removeAlert(at indexPath: IndexPath) {
        alertService.remove(indexPath: indexPath)
    }

    func updateAlert(value: Bool, at indexPath: IndexPath) {
        alertService.update(indexPath: indexPath, update: .enabled(value))
    }
}

extension FungibleTokenViewModel {

    enum TokenScriptWarningMessage {
        case warning(string: String)
        case undefined
    }

    enum ActionButtonState {
        case isDisplayed(Bool)
        case isEnabled(Bool)
        case noOption
    }

    struct ViewState {
        let navigationTitle: String
        let actions: [TokenInstanceAction]
    }

}
