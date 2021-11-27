// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum TokenObjectOrRpcServerPair {
    case tokenObject(TokenObject)
    case rpcServer(RPCServer)

    var canDelete: Bool {
        switch self {
        case .rpcServer:
            return false
        case .tokenObject(let token):
            guard !token.isInvalidated else { return false }
            if token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                return false
            }
            return true
        }
    }
}

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { WalletFilter.orderedTabs.map { $0.title } }

    private let filterTokensCoordinator: FilterTokensCoordinator
    var tokens: [TokenObject]

    var isSearchActive: Bool = false
    var filter: WalletFilter = .all {
        didSet {
            filteredTokens = filteredAndSortedTokens()
            refreshSections(walletConnectSessions: walletConnectSessions)
        }
    }
    var walletConnectSessions: Int = 0
    private (set) var sections: [TokensViewController.Section] = []

    private func refreshSections(walletConnectSessions count: Int) {
        if isSearchActive {
            sections = [.tokens]
        } else {
            if count == .zero {
                sections = [.filters, .addHideToken, .tokens]
            } else {
                sections = [.filters, .addHideToken, .activeWalletSession(count: count), .tokens]
            }
        }
    }

    lazy var filteredTokens: [TokenObjectOrRpcServerPair] = {
        return filteredAndSortedTokens()
    }()

    var headerBackgroundColor: UIColor {
        return .white
    }

    var walletDefaultTitle: String {
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
        case .assetsOnly, .collectiblesOnly, .type:
            return false
        }
    }

    var shouldShowCollectiblesCollectionView: Bool {
        switch filter {
        case .all, .currencyOnly, .assetsOnly, .keyword, .type:
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

    func item(for row: Int, section: Int) -> TokenObjectOrRpcServerPair {
        return filteredTokens[row]
    }

    func canDelete(for row: Int, section: Int) -> Bool {
        return item(for: row, section: section).canDelete
    }

    init(filterTokensCoordinator: FilterTokensCoordinator, tokens: [TokenObject]) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokens = TokensViewModel.functional.filterAwaySpuriousTokens(tokens)
    }

    func markTokenHidden(token: TokenObject) -> Bool {
        if let index = tokens.firstIndex(where: { $0.primaryKey == token.primaryKey }) {
            tokens.remove(at: index)
            filteredTokens = filteredAndSortedTokens()

            return true
        }

        return false
    }

    private func filteredAndSortedTokens() -> [TokenObjectOrRpcServerPair] {
        let displayedTokens = filterTokensCoordinator.filterTokens(tokens: tokens, filter: filter)
        let tokens = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
        switch filter {
        case .all, .type, .currencyOnly, .assetsOnly, .keyword:
            return TokensViewModel.functional.groupTokenObjectsWithServers(tokens: tokens)
        case .collectiblesOnly:
            return tokens.map { .tokenObject($0) }
        }
    }

    func nativeCryptoCurrencyToken(forServer server: RPCServer) -> TokenObject? {
        return tokens.first(where: { $0.primaryKey == TokensDataStore.etherToken(forServer: server).primaryKey })
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
            // .assetsOnly,
            // .collectiblesOnly,
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
        case .keyword, .type:
            return ""
        }
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}

extension TokensViewModel {
    class functional {}
}

extension TokensViewModel.functional {
    static func groupTokenObjectsWithServers(tokens: [TokenObject]) -> [TokenObjectOrRpcServerPair] {
        var servers: [RPCServer] = []
        var results: [TokenObjectOrRpcServerPair] = []

        for each in tokens {
            guard !servers.contains(each.server) else { continue }
            servers.append(each.server)
        }

        for each in servers {
            let tokens = tokens.filter { $0.server == each }.map { TokenObjectOrRpcServerPair.tokenObject($0) }
            guard !tokens.isEmpty else { continue }
            results.append(contentsOf: tokens)
        }

        return results
    }

    //Remove tokens that look unwanted in the Wallet tab
    static func filterAwaySpuriousTokens(_ tokens: [TokenObject]) -> [TokenObject] {
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
