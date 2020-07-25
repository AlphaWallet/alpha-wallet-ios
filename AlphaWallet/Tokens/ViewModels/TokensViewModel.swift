// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum TokensSection {
    case filter
    case addHideToken
    case filtered
    case deposit
    case loans 
}

private struct TokenFilteringResult {

    let loans: [TokenObject]
    let deposit: [TokenObject]
    let filtered: [TokenObject]

    var hasContant: Bool {
        return !loans.isEmpty || !deposit.isEmpty || !filtered.isEmpty
    }
}

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { WalletFilter.orderedTabs.map { $0.title } }

    private let filterTokensCoordinator: FilterTokensCoordinator
    var tokens: [TokenObject]
    let tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]

    var filter: WalletFilter = .all {
        didSet {
            filteringResult = filteredAndSortedTokenResult()
        }
    }

    private lazy var filteringResult: TokenFilteringResult = filteredAndSortedTokenResult()

    var headerBackgroundColor: UIColor {
        return .white
    }

    var title: String {
        return R.string.localizable.walletTokensTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var shouldShowBackupPromptViewHolder: Bool {
        //TODO show the prompt in both ASSETS and COLLECTIBLES tab too
        switch filter {
        case .all, .currencyOnly, .keyword:
            return true
        case .assetsOnly, .collectiblesOnly, .finances:
            return false
        }
    }

    var shouldShowCollectiblesCollectionView: Bool {
        switch filter {
        case .all, .currencyOnly, .assetsOnly, .keyword, .finances:
            return false
        case .collectiblesOnly:
            return hasContent
        }
    }

    var hasContent: Bool {
        return filteringResult.hasContant
    }

    func numberOfItems(section: Int) -> Int {
        switch filter {
        case .collectiblesOnly:
            return filteringResult.filtered.count
        case .all, .assetsOnly, .currencyOnly, .finances, .keyword:
            return 0
        }
    }

    func item(for row: Int, section: Int) -> TokenObject {
        switch sections[section] {
        case .addHideToken, .filter:
            return filteringResult.filtered[row]
        case .deposit:
            return filteringResult.deposit[row]
        case .filtered:
            return filteringResult.filtered[row]
        case .loans:
            return filteringResult.loans[row]
        }
    }

    func ticker(for token: TokenObject) -> CoinTicker? {
        return tickers[token.server]?[token.contractAddress]
    }

    func canDelete(for row: Int, section: Int) -> Bool {
        let token = item(for: row, section: section)
        guard !token.isInvalidated else { return false }
        if token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            return false
        }
        return true
    }

    init(filterTokensCoordinator: FilterTokensCoordinator, tokens: [TokenObject], tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokens = tokens
        self.tickers = tickers
    }

    func markTokenHidden(token: TokenObject) -> Bool {
        if let index = tokens.firstIndex(where: { $0.primaryKey == token.primaryKey }) {
            tokens.remove(at: index)
            filteringResult = filteredAndSortedTokenResult()

            return true
        }

        return false
    }

    private func filteredAndSortedTokenResult() -> TokenFilteringResult {
        
        var loans: [TokenObject] = []
        var deposit: [TokenObject] = []
        var filtered: [TokenObject] = []

        switch filter {
        case .finances:
            let displayedLoans = filterTokensCoordinator.loansFinancesTokens(tokens: tokens)
            let displayedDeposits = filterTokensCoordinator.depositFinancesTokens(tokens: tokens)

            loans = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedLoans)
            deposit = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedDeposits)
        case .all, .assetsOnly, .collectiblesOnly, .currencyOnly, .keyword:
            let displayedTokens = filterTokensCoordinator.filterTokens(tokens: tokens, filter: filter)

            filtered = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
        }

        return .init(loans: loans, deposit: deposit, filtered: filtered)
    }

    func nativeCryptoCurrencyToken(forServer server: RPCServer) -> TokenObject? {
        return tokens.first(where: { $0.primaryKey == TokensDataStore.etherToken(forServer: .main).primaryKey })
    }

    func amount(for token: TokenObject) -> Double {
        guard let tickers = tickers[token.server] else { return 0 }
        guard !token.valueBigInt.isZero, let tickersSymbol = tickers[token.contractAddress] else { return 0 }
        let tokenValue = EtherNumberFormatter.plain.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        return tokenValue * tickersSymbol.price_usd
    }

    func convertSegmentedControlSelectionToFilter(_ selection: SegmentedControl.Selection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }

    var sectionCount: Int {
        return sections.count
    }

    var sections: [TokensSection] {
        switch filter {
        case .finances:
            return [.filter, .deposit, .loans]
        case .all, .assetsOnly, .collectiblesOnly, .currencyOnly, .keyword:
            return [.filter, .addHideToken, .filtered]
        }
    }

    func heightForHeader(in section: Int) -> CGFloat {
        switch sections[section] {
        case .addHideToken, .filter:
            return 50.0
        case .loans:
            return filteringResult.loans.isEmpty ? 0.01 : 50.0
        case .deposit:
            return filteringResult.deposit.isEmpty ? 0.01 : 50.0
        case .filtered:
            return 0.01
        }
    }

    func numberOfRows(in section: Int) -> Int {
        switch sections[section] {
        case .addHideToken, .filter:
            return 0
        case .deposit:
            return filteringResult.deposit.count
        case .filtered:
            return filteringResult.filtered.count
        case .loans:
            return filteringResult.loans.count
        }
    }

    var depositTitleLabel: String {
        return R.string.localizable.aWalletTokensDeposit()
    }

    var loansTitleLabel: String {
        return R.string.localizable.aWalletTokensLoans()
    }
}

fileprivate extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
            .finances,
            .currencyOnly,
            .assetsOnly,
            .collectiblesOnly,
        ]
    }

    static func filter(fromIndex index: UInt) -> WalletFilter? {
        return WalletFilter.orderedTabs.first { $0.selectionIndex == index }
    }

    var title: String {
        switch self {
        case .all:
            return R.string.localizable.aWalletContentsFilterAllTitle()
        case .currencyOnly:
            return R.string.localizable.aWalletContentsFilterCurrencyOnlyTitle()
        case .assetsOnly:
            return R.string.localizable.aWalletContentsFilterAssetsOnlyTitle()
        case .collectiblesOnly:
            return R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle()
        case .keyword:
            return ""
        case .finances:
            return R.string.localizable.aWalletContentsFilterFinancesTitle()
        }
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}
