// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Combine
import AlphaWalletFoundation

struct FungibleTokenViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let updateAlert: AnyPublisher<(value: Bool, indexPath: IndexPath), Never>
    let removeAlert: AnyPublisher<IndexPath, Never>
}

struct FungibleTokenViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenViewModel.ViewState, Never>
    let activities: AnyPublisher<ActivityPageViewModel, Never>
    let alerts: AnyPublisher<PriceAlertsPageViewModel, Never>
}

final class FungibleTokenViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let coinTickersFetcher: CoinTickersFetcher
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private let tokensService: TokenViewModelState & TokenBalanceRefreshable
    private let activitiesService: ActivitiesServiceType
    private let alertService: PriceAlertServiceType
    private lazy var tokenHolder: TokenHolder = token.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account)
    private (set) var actions: [TokenInstanceAction] = []

    let session: WalletSession
    let assetDefinitionStore: AssetDefinitionStore
    var wallet: Wallet { session.account }
    lazy var tokenScriptFileStatusHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    let token: Token

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        return xmlHandler.tokenScriptStatus
    }

    var hasCoinTicker: Bool {
        return tokensService.tokenViewModel(for: token)?.balance.ticker != nil
    }

    lazy var tokenInfoPageViewModel = TokenInfoPageViewModel(token: token, coinTickersFetcher: coinTickersFetcher, tokensService: tokensService)

    let backgroundColor: UIColor = Colors.appBackground
    let sendButtonTitle: String = R.string.localizable.send()
    let receiveButtonTitle: String = R.string.localizable.receive()

    init(activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType, token: Token, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, coinTickersFetcher: CoinTickersFetcher, tokensService: TokenViewModelState & TokenBalanceRefreshable) {
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.token = token
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
        self.tokensService = tokensService
    }

    func tokenScriptWarningMessage(for action: TokenInstanceAction) -> TokenScriptWarningMessage? {
        let fungibleBalance = tokensService.tokenViewModel(for: token)?.balance.value
        if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
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
            let fungibleBalance = tokensService.tokenViewModel(for: token)?.balance.value
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
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
        input.appear.receive(on: RunLoop.main)
            .sink { [tokensService, token] _ in tokensService.refreshBalance(updatePolicy: .token(token: token)) }
            .store(in: &cancelable)

        input.removeAlert
            .sink { [alertService] in alertService.remove(indexPath: $0) }
            .store(in: &cancelable)

        input.updateAlert
            .sink { [alertService] in alertService.update(indexPath: $0.indexPath, update: .enabled($0.value)) }
            .store(in: &cancelable)

        activitiesService.start()
        
        let whenTokenHolderHasChanged = tokenHolder.objectWillChange
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenTokenActionsHasChanged = tokenActionsProvider.objectWillChange
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let tokenViewModel = tokensService.tokenViewModelPublisher(for: token)

        let actions = Publishers.MergeMany(tokenViewModel, whenTokenHolderHasChanged, whenTokenActionsHasChanged)
            .compactMap { _ in self.buildTokenActions() }
            .handleEvents(receiveOutput: { self.actions = $0 })

        let title = tokenViewModel.compactMap { $0?.tokenScriptOverrides?.titleInPluralForm }

        let activities = activitiesService.activitiesPublisher
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .receive(on: RunLoop.main)

        let alerts = alertService.alertsPublisher(forStrategy: .token(token))
            .map { PriceAlertsPageViewModel(alerts: $0) }
            .receive(on: RunLoop.main)

        let viewState = Publishers.CombineLatest(actions, title)
            .map { actions, title in FungibleTokenViewModel.ViewState(title: title, actions: actions) }

        return .init(viewState: viewState.eraseToAnyPublisher(),
                    activities: activities.eraseToAnyPublisher(),
                    alerts: alerts.eraseToAnyPublisher())
    }

    private func buildTokenActions() -> [TokenInstanceAction] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.name))")
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                return []
            case .erc20, .nativeCryptocurrency:
                let actions: [TokenInstanceAction] = [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]

                return actions + tokenActionsProvider.actions(token: token)
            }
        } else {
            switch token.type {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                return []
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
        let title: String
        let actions: [TokenInstanceAction]
    }

}
