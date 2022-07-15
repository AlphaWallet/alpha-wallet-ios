// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Combine

class FungibleTokenViewModel {

    enum TokenScriptWarningMessage {
        case warning(string: String)
        case undefined
    }

    enum ActionButtonState {
        case isDisplayed(Bool)
        case isEnabled(Bool)
        case noOption
    }

    private let coinTickersFetcher: CoinTickersFetcherType
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
    private (set) var tokenActionsProvider: SupportedTokenActionsProvider
    let transactionType: TransactionType
    let session: WalletSession
    let assetDefinitionStore: AssetDefinitionStore
    var wallet: Wallet { session.account }

    var navigationTitle: String {
        transactionType.tokenObject.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    lazy var tokenScriptFileStatusHandler = XMLHandler(token: transactionType.tokenObject, assetDefinitionStore: assetDefinitionStore)

    lazy var tokenHolder: TokenHolder? = {
        return validatedToken.flatMap { $0.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account) }
    }()

    var token: Token {
        return transactionType.tokenObject
    }

    var actions: [TokenInstanceAction] {
        guard let token = validatedToken else { return [] }
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions

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
                case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
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

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        if let token = validatedToken {
            let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
            return xmlHandler.tokenScriptStatus
        } else {
            assertImpossibleCodePath()
            return .value(.type2BadTokenScript(isDebugMode: false, message: "Unknown", reason: nil))
        }
    }

    var fungibleBalance: BigInt? {
        switch transactionType {
        case .nativeCryptocurrency:
            return session.tokenBalanceService.ethBalanceViewModel?.value
        case .erc20Token(let token, _, _):
            return token.value
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }

    lazy var actionsPublisher: AnyPublisher<[TokenInstanceAction], Never> = {
        let tokenHolderUpdates: AnyPublisher<Void, Never> = tokenHolder?.objectWillChange.eraseToAnyPublisher() ?? Empty(completeImmediately: true).eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let tokenActionsUpdates = tokenActionsProvider.objectWillChange
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let assetBodyChanges = assetDefinitionStore.assetBodyChanged(for: transactionType.contract)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let initialUpdate = Just<Void>(()).eraseToAnyPublisher()

        return Publishers.MergeMany(initialUpdate, tokenHolderUpdates, tokenActionsUpdates, assetBodyChanges)
            .compactMap { [weak self] _ in self?.actions }
            .eraseToAnyPublisher()
    }()

    var hasCoinTicker: Bool {
        switch transactionType {
        case .nativeCryptocurrency:
            let etherToken = session.tokenBalanceService.etherToken
            return session.tokenBalanceService.coinTicker(etherToken.addressAndRPCServer) != nil
        case .erc20Token(let token, _, _):
            return session.tokenBalanceService.coinTicker(token.addressAndRPCServer) != nil
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return false
        }
    }

    lazy var tokenInfoPageViewModel = TokenInfoPageViewModel(session: session, transactionType: transactionType, assetDefinitionStore: assetDefinitionStore, coinTickersFetcher: coinTickersFetcher)

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

    init(transactionType: TransactionType, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, coinTickersFetcher: CoinTickersFetcherType) {
        self.transactionType = transactionType
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
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

    func viewDidLoad() {
        refreshBalance()
        tokenInfoPageViewModel.fetchChartHistory()
    }

    private func refreshBalance() {
        switch transactionType {
        case .nativeCryptocurrency:
            session.tokenBalanceService.refresh(refreshBalancePolicy: .eth)
        case .erc20Token(let token, _, _):
            session.tokenBalanceService.refresh(refreshBalancePolicy: .token(token: token))
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }
    }

}
