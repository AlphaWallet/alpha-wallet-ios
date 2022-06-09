//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import Combine

class SelectTokenViewModel: ObservableObject {
    private var tokens: [Token] = []
    private let filter: WalletFilter
    private let tokenCollection: TokenCollection
    private var cancelable = Set<AnyCancellable>()
    private var selectedToken: Token?
    private let wallet: Wallet
    private let tokenBalanceService: TokenBalanceService
    private let eventsDataStore: NonActivityEventsDataStore
    private let assetDefinitionStore: AssetDefinitionStore

    private lazy var filteredTokens: [Token] = filteredAndSortedTokens()

    var headerBackgroundColor: UIColor = Colors.appBackground
    var navigationTitle: String = R.string.localizable.assetsSelectAssetTitle()
    var backgroundColor: UIColor = Colors.appBackground

    init(wallet: Wallet, tokenBalanceService: TokenBalanceService, tokenCollection: TokenCollection, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, filter: WalletFilter) {
        self.wallet = wallet
        self.tokenBalanceService = tokenBalanceService
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.tokenCollection = tokenCollection
        self.filter = filter
    }

    func numberOfItems() -> Int {
        return filteredTokens.count
    }

    func accessoryType(for indexPath: IndexPath) -> UITableViewCell.AccessoryType {
        guard let selectedToken = selectedToken else { return .none }

        let token = filteredTokens[indexPath.row]

        return selectedToken == token ? .checkmark : .none
    }

    func selectToken(at indexPath: IndexPath) -> Token {
        let token = token(at: indexPath)
        selectedToken = token

        return token
    }

    func fetch() {
        tokenCollection.fetch()
    }

    func viewDidLoad() {
        tokenCollection.tokensViewModel.sink { [weak self] viewModel in
            self?.tokens = viewModel.tokens
            self?.reloadTokens()
            self?.objectWillChange.send()
        }.store(in: &cancelable)
    }

    private func token(at indexPath: IndexPath) -> Token {
        return filteredTokens[indexPath.row]
    }

    private func reloadTokens() {
        filteredTokens = filteredAndSortedTokens()
    }

    private func filteredAndSortedTokens() -> [Token] {
        let displayedTokens = tokenCollection.tokensFilter.filterTokens(tokens: tokens, filter: filter)
        return tokenCollection.tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
    }

    func viewModel(for indexPath: IndexPath) -> ViewModelType {
        let token = token(at: indexPath)
        let accessoryType = accessoryType(for: indexPath)
        switch token.type {
        case .nativeCryptocurrency:
            let viewModel = EthTokenViewCellViewModel(token: token, ticker: tokenBalanceService.coinTicker(token.addressAndRPCServer), currencyAmount: tokenBalanceService.ethBalanceViewModel?.currencyAmountWithoutSymbol, assetDefinitionStore: assetDefinitionStore, accessoryType: accessoryType)
            return .nativeCryptocurrency(viewModel)
        case .erc20:
            let viewModel = FungibleTokenViewCellViewModel(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: wallet, ticker: tokenBalanceService.coinTicker(token.addressAndRPCServer), accessoryType: accessoryType)
            return .erc20(viewModel)
        case .erc721, .erc721ForTickets, .erc875, .erc1155:
            let viewModel = NonFungibleTokenViewCellViewModel(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: wallet, accessoryType: accessoryType)
            return .nonFungible(viewModel)
        }
    } 

    enum ViewModelType {
        case nativeCryptocurrency(EthTokenViewCellViewModel)
        case erc20(FungibleTokenViewCellViewModel)
        case nonFungible(NonFungibleTokenViewCellViewModel)
    }
}
