// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct AccountsViewModel {
    private var config: Config
    private let hdWallets: [Wallet]
    private let keystoreWallets: [Wallet]
    private let watchedWallets: [Wallet]
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator

    var sections: [AccountsSectionType] {
        switch configuration {
        case .changeWallets:
            return [.hdWallet, .keystoreWallet, .watchedWallet]
        case .summary:
            return [.summary, .hdWallet, .keystoreWallet, .watchedWallet]
        }
    }

    let configuration: AccountsCoordinatorViewModel.Configuration
    var addresses: [AlphaWallet.Address] {
        return (hdWallets + keystoreWallets + watchedWallets).compactMap { $0.address }
    }

    var subscribeForBalanceUpdates: Bool {
        switch configuration {
        case .changeWallets:
            return false
        case .summary:
            return true
        }
    }

    init(keystore: Keystore, config: Config, configuration: AccountsCoordinatorViewModel.Configuration, analyticsCoordinator: AnalyticsCoordinator) {
        self.config = config
        self.keystore = keystore
        self.configuration = configuration
        self.analyticsCoordinator = analyticsCoordinator
        hdWallets = keystore.wallets.filter { keystore.isHdWallet(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        keystoreWallets = keystore.wallets.filter { keystore.isKeystore(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        watchedWallets = keystore.wallets.filter { keystore.isWatched(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
    }

    subscript(indexPath: IndexPath) -> AccountViewModel? {
        guard let account = account(for: indexPath) else { return nil }
        let walletName = self.walletName(forAccount: account)

        return AccountViewModel(wallet: account, current: keystore.currentWallet, walletName: walletName, analyticsCoordinator: analyticsCoordinator)
    }

    var title: String {
        return configuration.navigationTitle
    }

    func walletName(forAccount account: Wallet) -> String? {
        let walletNames = config.walletNames
        return walletNames[account.address]
    }

    func numberOfItems(section: Int) -> Int {
        switch sections[section] {
        case .hdWallet:
            return hdWallets.count
        case .keystoreWallet:
            return keystoreWallets.count
        case .watchedWallet:
            return watchedWallets.count
        case .summary:
            return 1
        }
    }

    func canEditCell(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .hdWallet:
            return keystore.currentWallet != hdWallets[indexPath.row]
        case .keystoreWallet:
            return keystore.currentWallet != keystoreWallets[indexPath.row]
        case .watchedWallet:
            return keystore.currentWallet != watchedWallets[indexPath.row]
        case .summary:
            return false
        }
    }

    //We don't show the section headers unless there are 2 "types" of wallets
    private func shouldHideAllSectionHeaders() -> Bool {
        if keystoreWallets.isEmpty && watchedWallets.isEmpty {
            return true
        }
        if hdWallets.isEmpty && watchedWallets.isEmpty {
            return true
        }
        return false
    }

    func shouldHideHeader(in section: Int) -> (shouldHide: Bool, section: AccountsSectionType) {
        let shouldHideSectionHeaders = shouldHideAllSectionHeaders()
        switch sections[section] {
        case .hdWallet:
            return (hdWallets.isEmpty, .hdWallet)
        case .keystoreWallet:
            switch configuration {
            case .changeWallets:
                return (shouldHideSectionHeaders || keystoreWallets.isEmpty, .keystoreWallet)
            case .summary:
                return (keystoreWallets.isEmpty, .keystoreWallet)
            }
        case .watchedWallet:
            switch configuration {
            case .changeWallets:
                return (shouldHideSectionHeaders || watchedWallets.isEmpty, .watchedWallet)
            case .summary:
                return (watchedWallets.isEmpty, .watchedWallet)
            }
        case .summary:
            return (shouldHide: false, section: .summary)
        }
    }

    func account(for indexPath: IndexPath) -> Wallet? {
        switch sections[indexPath.section] {
        case .hdWallet:
            return hdWallets[indexPath.row]
        case .keystoreWallet:
            return keystoreWallets[indexPath.row]
        case .watchedWallet:
            return watchedWallets[indexPath.row]
        case .summary:
            return nil
        }
    }

}

enum AccountsSectionType: Int, CaseIterable {
    case summary
    case hdWallet
    case keystoreWallet
    case watchedWallet

    var title: String {
        switch self {
        case .summary:
            return R.string.localizable.walletTypesSummary().uppercased()
        case .hdWallet:
            return R.string.localizable.walletTypesHdWallets().uppercased()
        case .keystoreWallet:
            return R.string.localizable.walletTypesKeystoreWallets().uppercased()
        case .watchedWallet:
            return R.string.localizable.walletTypesWatchedWallets().uppercased()
        }
    }
}
