// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum TokenOrRpcServer {
    case token(Token)
    case rpcServer(RPCServer)

    var token: Token? {
        switch self {
        case .rpcServer:
            return nil
        case .token(let token):
            return token
        }
    }

    var canDelete: Bool {
        switch self {
        case .rpcServer:
            return false
        case .token(let token):
            //guard !token.isInvalidated else { return false }
            if token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                return false
            }
            return true
        }
    }
}

struct CollectiblePairs: Hashable {
    let left: Token
    let right: Token?
}

extension TokensViewModel {
    enum Section: Equatable {
        case walletSummary
        case filters
        case testnetTokens
        case search
        case tokens
        case collectiblePairs
        case activeWalletSession(count: Int)
    }
}

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { WalletFilter.orderedTabs.map { $0.title } }

    private let tokensFilter: TokensFilter
    private (set) var tokens: [Token]
    let config: Config
    var isSearchActive: Bool = false
    var filter: WalletFilter = .all {
        didSet {
            filteredTokens = filteredAndSortedTokens()
            refreshSections(walletConnectSessions: walletConnectSessions)
        }
    }
    var walletConnectSessions: Int = 0
    private (set) var sections: [Section] = []
    private var tokenListSection: Section = .tokens

    private func refreshSections(walletConnectSessions count: Int) {
        let varyTokenOrCollectiblePeirsSection: Section = {
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter:
                return .tokens
            case .collectiblesOnly:
                return .collectiblePairs
            }
        }()

        if isSearchActive {
            sections = [varyTokenOrCollectiblePeirsSection]
        } else {
            let initialSections: [Section]
            let testnetHeaderSections: [Section]

            if config.enabledServers.allSatisfy({ $0.isTestnet }) {
                testnetHeaderSections = [.testnetTokens]
            } else {
                testnetHeaderSections = []
            }

            if count == .zero {
                initialSections = [.walletSummary, .filters, .search]
            } else {
                initialSections = [.walletSummary, .filters, .search, .activeWalletSession(count: count)]
            }
            sections = initialSections + testnetHeaderSections + [varyTokenOrCollectiblePeirsSection]
        }
        tokenListSection = varyTokenOrCollectiblePeirsSection
    }

    //NOTE: For case with empty tokens list we want
    func isBottomSeparatorLineHiddenForTestnetHeader(section: Int) -> Bool {
        switch sections[section] {
        case .walletSummary, .filters, .activeWalletSession, .search, .tokens, .collectiblePairs:
            return true
        case .testnetTokens:
            if let index = sections.firstIndex(where: { $0 == tokenListSection }) {
                return numberOfItems(for: Int(index)) == 0
            } else {
                return true
            }
        }
    }

    lazy var filteredTokens: [TokenOrRpcServer] = {
        return filteredAndSortedTokens()
    }()

    var headerBackgroundColor: UIColor {
        return .white
    }

    var walletDefaultTitle: String {
        return R.string.localizable.walletTokensTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var shouldShowBackupPromptViewHolder: Bool {
        //TODO show the prompt in both ASSETS and COLLECTIBLES tab too
        switch filter {
        case .all, .keyword:
            return true
        case .assets, .collectiblesOnly, .filter, .defi, .governance:
            return false
        }
    }

    var hasContent: Bool {
        return !collectiblePairs.isEmpty
    }

    var shouldShowCollectiblesCollectionView: Bool {
        switch filter {
        case .all, .defi, .governance, .assets, .keyword, .filter:
            return false
        case .collectiblesOnly:
            return hasContent
        }
    }

    func heightForHeaderInSection(for section: Int) -> CGFloat {
        switch sections[section] {
        case .walletSummary:
            return 80
        case .filters:
            return DataEntry.Metric.Tokens.Filter.height
        case .activeWalletSession:
            return 80
        case .search, .testnetTokens:
            return DataEntry.Metric.AddHideToken.Header.height
        case .tokens, .collectiblePairs:
            return 0.01
        }
    }

    func numberOfItems(for section: Int) -> Int {
        switch sections[section] {
        case .search, .testnetTokens, .walletSummary, .filters, .activeWalletSession:
            return 0
        case .tokens, .collectiblePairs:
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter:
                return filteredTokens.count
            case .collectiblesOnly:
                return collectiblePairs.count
            }
        }
    }

    var collectiblePairs: [CollectiblePairs] {
        let tokens = filteredTokens.compactMap { $0.token }
        return tokens.chunked(into: 2).compactMap { elems -> CollectiblePairs? in
            guard let left = elems.first else { return nil }

            let right = (elems.last?.contractAddress.sameContract(as: left.contractAddress) ?? false) ? nil : elems.last
            return .init(left: left, right: right)
        }
    }

    func item(for row: Int, section: Int) -> TokenOrRpcServer {
        return filteredTokens[row]
    }

    func canDelete(for row: Int, section: Int) -> Bool {
        return item(for: row, section: section).canDelete
    }

    init(tokensFilter: TokensFilter, tokens: [Token], config: Config) {
        self.tokensFilter = tokensFilter
        self.tokens = tokens
        self.config = config
    }

    func markTokenHidden(token: Token) -> Bool {
        if let index = tokens.firstIndex(where: { $0.primaryKey == token.primaryKey }) {
            tokens.remove(at: index)
            filteredTokens = filteredAndSortedTokens()

            return true
        }

        return false
    }

    func cellHeight(for indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .tokens, .testnetTokens:
            switch item(for: indexPath.row, section: indexPath.section) {
            case .rpcServer:
                return Style.Wallet.Header.height
            case .token:
                return Style.Wallet.Row.height
            }
        case .search, .walletSummary, .filters, .activeWalletSession:
            return Style.Wallet.Row.height
        case .collectiblePairs:
            return Style.Wallet.Row.collectiblePairsHeight
        }
    }

    private func filteredAndSortedTokens() -> [TokenOrRpcServer] {
        let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
        let tokens = tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
        switch filter {
        case .all, .filter, .defi, .governance, .assets, .keyword:
            return TokensViewModel.functional.groupTokensByServers(tokens: tokens)
        case .collectiblesOnly:
            return tokens.map { .token($0) }
        }
    }

    func nativeCryptoCurrencyToken(forServer server: RPCServer) -> Token? {
        return tokens.first(where: { $0.primaryKey == MultipleChainsTokensDataStore.functional.etherToken(forServer: server).primaryKey })
    }

    func convertSegmentedControlSelectionToFilter(_ selection: ControlSelection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }

    func indexPathArrayForDeletingAt(indexPath current: IndexPath) -> [IndexPath] {
        let canRemoveCurrentItem: Bool  = item(for: current.row, section: current.section).isRemovable
        let canRemovePreviousItem: Bool = current.row > 0 ? item(for: current.row - 1, section: current.section).isRemovable : false
        let canRemoveNextItem: Bool = {
            guard (current.row + 1) < filteredTokens.count else { return false }
            return item(for: current.row + 1, section: current.section).isRemovable
        }()
        switch (canRemovePreviousItem, canRemoveCurrentItem, canRemoveNextItem) {
            // Truth table for deletion
            // previous, current, next
            // 0, 0, 0
            // return []
            // 0, 0, 1
            // return []
            // 0, 1, 0
            // return [current.previous, current]
            // 0, 1, 1
            // return [current]
            // 1, 0, 0
            // return []
            // 1, 0, 1
            // return []
            // 1, 1, 0
            // return [current]
            // 1, 1, 1
            // return [current]
        case (_, false, _):
            return []
        case (false, true, false):
            return [current.previous, current]
        default:
            return [current]
        }
    }
}

fileprivate extension TokenOrRpcServer {
    var isRemovable: Bool {
        switch self {
        case .rpcServer:
            return false
        case .token:
            return true
        }
    }
}

extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
            .assets,
            .collectiblesOnly,
            .defi,
            .governance,
        ]
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}

fileprivate extension WalletFilter {
    static func filter(fromIndex index: UInt) -> WalletFilter? {
        return WalletFilter.orderedTabs.first { $0.selectionIndex == index }
    }

    var title: String {
        switch self {
        case .all:
            return R.string.localizable.aWalletContentsFilterAllTitle()
        case .defi:
            return R.string.localizable.aWalletContentsFilterDefiTitle()
        case .governance:
            return R.string.localizable.aWalletContentsFilterGovernanceTitle()
        case .assets:
            return R.string.localizable.aWalletContentsFilterAssetsOnlyTitle()
        case .collectiblesOnly:
            return R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle()
        case .keyword, .filter:
            return ""
        }
    }
}

extension TokensViewModel {
    class functional {}
}

extension TokensViewModel.functional {
    static func groupTokensByServers(tokens: [Token]) -> [TokenOrRpcServer] {
        var servers: [RPCServer] = []
        var results: [TokenOrRpcServer] = []

        for each in tokens {
            guard !servers.contains(each.server) else { continue }
            servers.append(each.server)
        }

        for each in servers {
            let tokens = tokens.filter { $0.server == each }.map { TokenOrRpcServer.token($0) }
            guard !tokens.isEmpty else { continue }

            results.append(.rpcServer(each))
            results.append(contentsOf: tokens)
        }

        return results
    }

    //Remove tokens that look unwanted in the Wallet tab
    static func filterAwaySpuriousTokens(_ tokens: [Token]) -> [Token] {
        tokens.filter {
            switch $0.type {
            case .nativeCryptocurrency, .erc20, .erc875, .erc721, .erc721ForTickets:
                return !($0.name.isEmpty && $0.symbol.isEmpty && $0.decimals == 0)
            case .erc1155:
                return true
            }
        }
    }
}

fileprivate extension IndexPath {
    var previous: IndexPath {
        IndexPath(row: row - 1, section: section)
    }
}
