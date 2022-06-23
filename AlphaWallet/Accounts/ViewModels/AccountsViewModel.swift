// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine
import Result
import UIKit

class AccountsViewModel: ObservableObject {
    private var config: Config
    private var hdWallets: [Wallet] = []
    private var keystoreWallets: [Wallet] = []
    private var watchedWallets: [Wallet] = []
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let walletBalanceService: WalletBalanceService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    private var reloadBalanceSubject: PassthroughSubject<ReloadState, Never> = .init()
    private lazy var getWalletName = GetWalletName(config: config, domainResolutionService: domainResolutionService)
    private var sections: [Section] {
        switch configuration {
        case .changeWallets:
            return [.hdWallet, .keystoreWallet, .watchedWallet]
        case .summary:
            return [.summary, .hdWallet, .keystoreWallet, .watchedWallet]
        }
    }
    var numberOfSections: Int { sections.count }
    let configuration: AccountsCoordinatorViewModel.Configuration
    var allowsAccountDeletion: Bool = false
    var subscribeForBalanceUpdates: Bool {
        switch configuration {
        case .changeWallets:
            return false
        case .summary:
            return true
        }
    }

    var activeWalletIndexPath: IndexPath? {
        keystore.currentWallet.flatMap { indexPath(for: $0) }
    }

    lazy var walletSummaryViewModel: WalletSummaryViewModel = {
        return .init(walletSummary: walletBalanceService.walletsSummaryPublisher, config: config)
    }()

    var hasWallets: Bool {
        return keystore.hasWallets
    }

    var reloadBalancePublisher: AnyPublisher<ReloadState, Never> {
        reloadBalanceSubject.eraseToAnyPublisher()
    }

    var title: String {
        return configuration.navigationTitle
    }

    var backgroundColor: UIColor = GroupedTable.Color.background

    init(keystore: Keystore, config: Config, configuration: AccountsCoordinatorViewModel.Configuration, analyticsCoordinator: AnalyticsCoordinator, walletBalanceService: WalletBalanceService, blockiesGenerator: BlockiesGenerator, domainResolutionService: DomainResolutionServiceType) {
        self.config = config
        self.keystore = keystore
        self.configuration = configuration
        self.analyticsCoordinator = analyticsCoordinator
        self.walletBalanceService = walletBalanceService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService

        reload()
    }

    func heightForHeader(in section: Int) -> CGFloat {
        shouldHideHeader(in: section).shouldHide ? .leastNormalMagnitude : UITableView.automaticDimension
    }

    func reload() {
        reloadWallets()
    }

    func set(walletName: String, for wallet: AlphaWallet.Address) {
        if walletName.isEmpty {
            config.deleteWalletName(forAccount: wallet)
        } else {
            config.saveWalletName(walletName, forAddress: wallet)
        }
        reload()
        objectWillChange.send()
    }

    private func reloadWallets() {
        hdWallets = keystore.wallets.filter { keystore.isHdWallet(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        keystoreWallets = keystore.wallets.filter { keystore.isKeystore(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
        watchedWallets = keystore.wallets.filter { keystore.isWatched(wallet: $0) }.sorted { $0.address.eip55String < $1.address.eip55String }
    }

    func reloadBalance() {
        reloadBalanceSubject.send(.fetching)
        walletBalanceService.refreshBalance(updatePolicy: .all, wallets: keystore.wallets)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.reloadBalanceSubject.send(.done)
        }
    }

    func delete(account: Wallet) -> Result<Void, KeystoreError> {
        return keystore.delete(wallet: account)
    }

    func viewModel(at indexPath: IndexPath) -> ViewModelType {
        switch sections[indexPath.section] {
        case .hdWallet, .keystoreWallet, .watchedWallet:
            guard let account = account(for: indexPath) else { return .undefined }
            let viewModel = AccountViewModel(analyticsCoordinator: analyticsCoordinator, getWalletName: getWalletName, blockiesGenerator: blockiesGenerator, subscribeForBalanceUpdates: subscribeForBalanceUpdates, walletBalanceService: walletBalanceService, wallet: account, current: keystore.currentWallet)

            return .wallet(viewModel)
        case .summary:
            return .summary(walletSummaryViewModel)
        }
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
        guard allowsAccountDeletion else { return false }
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

    func shouldHideHeader(in section: Int) -> (shouldHide: Bool, section: Section) {
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

    private func indexPath(for wallet: Wallet) -> IndexPath? {
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

extension AccountsViewModel {
    enum ViewModelType {
        case wallet(AccountViewModel)
        case summary(WalletSummaryViewModel)
        case undefined
    }

    enum Section: Int, CaseIterable {
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

    enum ReloadState {
        case fetching
        case done
        case failure(error: Error)
    }

}
