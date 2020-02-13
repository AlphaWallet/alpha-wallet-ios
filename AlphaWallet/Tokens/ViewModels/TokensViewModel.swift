// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    static let segmentedControlTitles = WalletFilter.orderedTabs.map { $0.title }

    private let assetDefinitionStore: AssetDefinitionStore
    private let tokens: [TokenObject]
    private let tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]

    private var amount: String? {
        var totalAmount: Double = 0
        filteredTokens.forEach { token in
            totalAmount += amount(for: token)
        }
        guard totalAmount != 0 else { return "--" }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }

    var filter: WalletFilter = .all {
        didSet {
            filteredTokens = getFilteredtokens()
        }
    }

    lazy var filteredTokens: [TokenObject] = {
        return getFilteredtokens()
    }()
    var headerBackgroundColor: UIColor {
        return .white
    }

    var title: String {
        return R.string.localizable.walletTokensTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var shouldShowBackupPromptViewHolder: Bool {
        //TODO show the prompt in both ASSETS and COLLECTIBLES tab too
        switch filter {
        case .all, .currencyOnly, .keyword:
            return true
        case .assetsOnly, .collectiblesOnly:
            return false
        }
    }


    var shouldShowCollectiblesCollectionView: Bool {
        switch filter {
        case .all, .currencyOnly, .assetsOnly, .keyword:
            return false
        case .collectiblesOnly:
            return hasContent
        }
    }

    var hasContent: Bool {
        return !filteredTokens.isEmpty
    }

    func numberOfItems() -> Int {
        return filteredTokens.count
    }

    func item(for row: Int, section: Int) -> TokenObject {
        return filteredTokens[row]
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

    init(assetDefinitionStore: AssetDefinitionStore, tokens: [TokenObject], tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokens = tokens
        self.tickers = tickers
    }

    private func getFilteredtokens() -> [TokenObject] {
        switch filter {
        case .all:
            return tokens
        case .currencyOnly:
            return tokens.filter { $0.type == .nativeCryptocurrency || $0.type == .erc20 }
        case .assetsOnly:
            return tokens.filter { $0.type != .nativeCryptocurrency && $0.type != .erc20 }
        case .collectiblesOnly:
            return tokens.filter { $0.type == .erc721 && !$0.balance.isEmpty }
        case .keyword(let keyword):
            let lowercasedKeyword = keyword.trimmed.lowercased()
            if lowercasedKeyword.isEmpty {
                return tokens
            } else {
                return tokens.filter {
                    if keyword.lowercased() == "erc20" || keyword.lowercased() == "erc 20" {
                        return $0.type == .erc20
                    } else if keyword.lowercased() == "erc721" || keyword.lowercased() == "erc 721" {
                        return $0.type == .erc721
                    } else if keyword.lowercased() == "erc875" || keyword.lowercased() == "erc 875" {
                        return $0.type == .erc875
                    } else if keyword.lowercased() == "tokenscript" {
                        let xmlHandler = XMLHandler(contract: $0.contractAddress, assetDefinitionStore: assetDefinitionStore)
                        return xmlHandler.hasAssetDefinition && xmlHandler.server == $0.server
                    } else {
                        return $0.name.trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.symbol.trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.contractAddress.eip55String.lowercased().contains(lowercasedKeyword) ||
                                $0.title(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(lowercasedKeyword)
                    }
                }
            }
        }
    }

    func nativeCryptoCurrencyToken(forServer server: RPCServer) -> TokenObject? {
        return tokens.first(where: { $0.primaryKey == TokensDataStore.etherToken(forServer: .main).primaryKey })
    }

    func amount(for token: TokenObject) -> Double {
        guard let tickers = tickers[token.server] else { return 0 }
        guard !token.valueBigInt.isZero, let tickersSymbol = tickers[token.contractAddress] else { return 0 }
        let tokenValue = CurrencyFormatter.plainFormatter.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        let price = Double(tickersSymbol.price_usd) ?? 0
        return tokenValue * price
    }

    func convertSegmentedControlSelectionToFilter(_ selection: SegmentedControl.Selection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }
}

fileprivate extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
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
        }
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}
