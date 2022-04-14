// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine

struct AccountsViewModel {
    private var config: Config
    private let hdWallets: [Wallet]
    private let keystoreWallets: [Wallet]
    private let watchedWallets: [Wallet]
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let walletBalanceService: WalletBalanceService

    var sections: [AccountsSectionType] {
        switch configuration {
        case .changeWallets:
            return [.hdWallet, .keystoreWallet, .watchedWallet]
        case .summary:
            return [.summary, .hdWallet, .keystoreWallet, .watchedWallet]
        }
    }

    let configuration: AccountsCoordinatorViewModel.Configuration
    var wallets: [Wallet]

    var subscribeForBalanceUpdates: Bool {
        switch configuration {
        case .changeWallets:
            return false
        case .summary:
            return true
        }
    }

    var activeWalletIndexPath: IndexPath? {
        guard let wallet = keystore.currentWallet, let indexPath = indexPath(for: wallet) else { return nil }
        return indexPath
    }
    private let generator = BlockiesGenerator()

    init(keystore: Keystore, config: Config, configuration: AccountsCoordinatorViewModel.Configuration, analyticsCoordinator: AnalyticsCoordinator, walletBalanceService: WalletBalanceService) {
        self.wallets = keystore.wallets
        self.config = config
        self.keystore = keystore
        self.configuration = configuration
        self.analyticsCoordinator = analyticsCoordinator
        self.walletBalanceService = walletBalanceService
        hdWallets = keystore.wallets.filter { keystore.isHdWallet(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        keystoreWallets = keystore.wallets.filter { keystore.isKeystore(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        watchedWallets = keystore.wallets.filter { keystore.isWatched(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
    }

    subscript(indexPath: IndexPath) -> AccountViewModel? {
        guard let account = account(for: indexPath) else { return nil }

        let walletName = self.walletName(forAccount: account)
        let apprecation24hour = walletBalanceService
            .walletBalance(wallet: account)
            .map { balance -> NSAttributedString in
                if self.subscribeForBalanceUpdates {
                    return AccountViewModel.apprecation24hourAttributedString(for: balance)
                } else {
                    return .init()
                }
            }.eraseToAnyPublisher()

        let balance = walletBalanceService.walletBalance(wallet: account)
            .map { balance -> NSAttributedString in
                return AccountViewModel.balanceAttributedString(for: balance.totalAmountString)
            }.eraseToAnyPublisher()

        let blockiesImage = generator.promise(address: account.address, size: 8, scale: 5)
            .publisher
            .prepend(BlockiesImage.defaulBlockieImage)
            .replaceError(with: BlockiesImage.defaulBlockieImage)
            .handleEvents(receiveOutput: { value in
                guard value.isEnsAvatar else { return }
                analyticsCoordinator.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
            })
            .eraseToAnyPublisher()

        return AccountViewModel(wallet: account, current: keystore.currentWallet, walletName: walletName, apprecation24hour: apprecation24hour, balance: balance, blockiesImage: blockiesImage)
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

    func indexPath(for wallet: Wallet) -> IndexPath? {
        guard let sectionIndex = sections.firstIndex(where: { sectionType in
            switch sectionType {
            case .summary:
                return false
            case .hdWallet:
                return keystore.isHdWallet(wallet: wallet)
            case .keystoreWallet:
                return keystore.isKeystore(wallet: wallet)
            case .watchedWallet:
                return keystore.isWatched(wallet: wallet)
            }
        }) else { return nil }
        switch sections[sectionIndex] {
        case .summary:
            return nil
        case .hdWallet:
            guard let rowIndex = hdWallets.firstIndex(where: { indexWallet in
                indexWallet == wallet
            }) else { return nil }
            return IndexPath(row: rowIndex, section: sectionIndex)
        case .keystoreWallet:
            guard let rowIndex = keystoreWallets.firstIndex(where: { indexWallet in
                indexWallet == wallet
            }) else { return nil }
            return IndexPath(row: rowIndex, section: sectionIndex)
        case .watchedWallet:
            guard let rowIndex = watchedWallets.firstIndex(where: { indexWallet in
                indexWallet == wallet
            }) else { return nil }
            return IndexPath(row: rowIndex, section: sectionIndex)
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
