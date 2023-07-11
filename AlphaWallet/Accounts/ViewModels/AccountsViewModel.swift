// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine
import UIKit
import AlphaWalletFoundation
import CombineExt

struct AccountsViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
    let copyToClipboard: AnyPublisher<IndexPath, Never>
    let deleteWallet: AnyPublisher<IndexPath, Never>
}

struct AccountsViewModelOutput {
    let viewState: AnyPublisher<AccountsViewModel.ViewState, Never>
    let reloadBalanceState: AnyPublisher<Loadable<Void, Error>, Never>
    let walletDelated: AnyPublisher<Wallet, Never>
    let copiedToClipboard: AnyPublisher<String, Never>
}

final class AccountsViewModel {
    private var viewModels: [AccountsViewModel.SectionViewModel] = []
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let walletBalanceService: WalletBalanceService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainNameResolutionServiceType
    private var cancellable = Set<AnyCancellable>()

    private lazy var getWalletName = GetWalletName(domainResolutionService: domainResolutionService)
    private var sections: [AccountsViewModel.Section] {
        switch configuration {
        case .changeWallets:
            return [.hdWallet, .keystoreWallet, .hardwareWallet, .watchedWallet]
        case .summary:
            return [.summary, .hdWallet, .keystoreWallet, .hardwareWallet, .watchedWallet]
        }
    }

    let configuration: AccountsCoordinatorViewModel.Configuration
    var allowsAccountDeletion: Bool = false
    private var displayBalanceApprecation: Bool {
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

    var hasWallets: Bool {
        return keystore.hasWallets
    }

    init(keystore: Keystore,
         configuration: AccountsCoordinatorViewModel.Configuration,
         analytics: AnalyticsLogger,
         walletBalanceService: WalletBalanceService,
         blockiesGenerator: BlockiesGenerator,
         domainResolutionService: DomainNameResolutionServiceType) {

        self.keystore = keystore
        self.configuration = configuration
        self.analytics = analytics
        self.walletBalanceService = walletBalanceService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
    }

    func heightForHeader(in section: Int) -> CGFloat {
        shouldHideHeader(in: section).shouldHide ? .leastNormalMagnitude : UITableView.automaticDimension
    }

    func transform(input: AccountsViewModelInput) -> AccountsViewModelOutput {

        deleteWallet(input: input.deleteWallet)
            .sink { _ in }
            .store(in: &cancellable)

        let copiedToClipboard = copyToClipboard(input: input.copyToClipboard)

        let reloadBalanceState = reloadBalance(input: input.pullToRefresh)

        let accountRowViewModels = Publishers.Merge(input.willAppear, reloadBalanceState.mapToVoid().eraseToAnyPublisher())
            .flatMapLatest { [keystore] _ in keystore.walletsPublisher }
            .map { $0.map { self.buildAccountRowViewModel(wallet: $0) } }
            .flatMapLatest { $0.combineLatest() }

        let walletsSummary = input.willAppear
            .flatMapLatest { [walletBalanceService] _ in walletBalanceService.walletsSummary }
            .map { WalletSummaryViewModel(walletSummary: $0) }

        let viewState = Publishers.CombineLatest(accountRowViewModels, walletsSummary)
            .map { self.buildViewModels(sections: self.sections, accountViewModels: $0, summary: $1) }
            .handleEvents(receiveOutput: { self.viewModels = $0 })
            .map { self.buildSnapshot(for: $0) }
            .map { [configuration] snapshot in AccountsViewModel.ViewState(title: configuration.title, snapshot: snapshot) }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            reloadBalanceState: reloadBalanceState,
            walletDelated: keystore.didRemoveWallet,
            copiedToClipboard: copiedToClipboard.eraseToAnyPublisher())
    }

    private func reloadBalance(input: AnyPublisher<Void, Never>) -> AnyPublisher<Loadable<Void, Error>, Never> {
        input.map { _ in Loadable<Void, Error>.loading }
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { [walletBalanceService, keystore] _ in
                walletBalanceService.refreshBalance(updatePolicy: .all, wallets: keystore.wallets)
            })
            .map { _ in Loadable<Void, Error>.done(()) }
            .share()
            .eraseToAnyPublisher()
    }

    private func deleteWallet(input: AnyPublisher<IndexPath, Never>) -> AnyPublisher<Void, Never> {
        input.compactMap { self.account(for: $0) }
            .map { [keystore] wallet in keystore.delete(wallet: wallet) }
            .eraseToAnyPublisher()
    }

    private func copyToClipboard(input: AnyPublisher<IndexPath, Never>) -> AnyPublisher<String, Never> {
        input.compactMap { self.account(for: $0) }
            .map { wallet -> String in
                UIPasteboard.general.string = wallet.address.eip55String
                return R.string.localizable.copiedToClipboard()
            }.eraseToAnyPublisher()
    }

    private func buildSnapshot(for viewModels: [AccountsViewModel.SectionViewModel]) -> AccountsViewModel.Snapshot {
        var snapshot = AccountsViewModel.Snapshot()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }

    private func buildAccountRowViewModel(wallet: Wallet) -> AnyPublisher<AccountRowViewModel, Never> {
        let balance = walletBalanceService.walletBalance(for: wallet)
        let blockieImage = blockiesGenerator.getBlockieOrEnsAvatarImage(address: wallet.address, fallbackImage: BlockiesImage.defaulBlockieImage)
            .handleEvents(receiveOutput: { [analytics] value in
                guard value.isEnsAvatar else { return }
                analytics.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
            })

        let addressOrEnsName = getWalletName.assignedNameOrEns(for: wallet.address)
            .map { [wallet] ensOrName in
                if let ensOrName = ensOrName {
                    return "\(ensOrName) | \(wallet.address.truncateMiddle)"
                } else {
                    return wallet.address.eip55String
                }
            }.prepend(wallet.address.eip55String)

        return Publishers.CombineLatest3(balance, blockieImage, addressOrEnsName)
            .map { AccountRowViewModel(wallet: wallet, blockie: $0.1, addressOrEnsName: $0.2, balance: $0.0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> [AccountsViewModel.SwipeAction] {
        var actions: [AccountsViewModel.SwipeAction] = [.copyToClipboard]
        if canDeleteWallet(at: indexPath) {
            actions += [.deleteWallet]
        }
        return actions
    }

    private func account(for indexPath: IndexPath) -> Wallet? {
        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            return viewModel.wallet
        case .summary:
            return .none
        }
    }

    func shouldHideHeader(in section: Int) -> (shouldHide: Bool, section: Section) {
        let shouldHideSectionHeaders = shouldHideAllSectionHeaders()
        switch sections[section] {
        case .hdWallet:
            let isHdWalletsEmpty = viewModels[section].views.isEmpty
            return (isHdWalletsEmpty, .hdWallet)
        case .keystoreWallet:
            let isKeystoreWalletsEmpty = viewModels[section].views.isEmpty
            switch configuration {
            case .changeWallets:
                return (shouldHideSectionHeaders || isKeystoreWalletsEmpty, .keystoreWallet)
            case .summary:
                return (isKeystoreWalletsEmpty, .keystoreWallet)
            }
        case .watchedWallet:
            let isWatchedWalletsEmpty = viewModels[section].views.isEmpty
            switch configuration {
            case .changeWallets:
                return (shouldHideSectionHeaders || isWatchedWalletsEmpty, .watchedWallet)
            case .summary:
                return (isWatchedWalletsEmpty, .watchedWallet)
            }
        case .hardwareWallet:
            let isHardwareWalletsEmpty = viewModels[section].views.isEmpty
            switch configuration {
            case .changeWallets:
                return (shouldHideSectionHeaders || isHardwareWalletsEmpty, .hardwareWallet)
            case .summary:
                return (isHardwareWalletsEmpty, .hardwareWallet)
            }
        case .summary:
            return (shouldHide: false, section: .summary)
        }
    }

    private func buildViewModels(sections: [Section], accountViewModels: [AccountRowViewModel], summary: WalletSummaryViewModel) -> [SectionViewModel] {
        sections.map { section in
            switch section {
            case .summary:
                return .init(section: section, views: [.summary(summary)])
            case .hdWallet:
                let views: [ViewModelType] = accountViewModels
                    .filter { $0.wallet.origin == .hd }
                    .sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                    .map {
                        let viewModel = AccountViewModel(
                            displayBalanceApprecation: displayBalanceApprecation,
                            accountRowViewModel: $0,
                            current: keystore.currentWallet)

                        return .wallet(viewModel)
                    }
                return .init(section: section, views: views)
            case .keystoreWallet:
                let views: [ViewModelType] = accountViewModels
                    .filter { $0.wallet.origin == .privateKey }
                    .sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                    .map {
                        let viewModel = AccountViewModel(
                            displayBalanceApprecation: displayBalanceApprecation,
                            accountRowViewModel: $0,
                            current: keystore.currentWallet)

                        return .wallet(viewModel)
                    }
                return .init(section: section, views: views)
            case .watchedWallet:
                let views: [ViewModelType] = accountViewModels
                    .filter { $0.wallet.origin == .watch }
                    .sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                    .map {
                        let viewModel = AccountViewModel(
                            displayBalanceApprecation: displayBalanceApprecation,
                            accountRowViewModel: $0,
                            current: keystore.currentWallet)

                        return .wallet(viewModel)
                    }
                return .init(section: section, views: views)
            case .hardwareWallet:
                let views: [ViewModelType] = accountViewModels
                    .filter { $0.wallet.origin == .hardware }
                    .sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                    .map {
                        let viewModel = AccountViewModel(
                            displayBalanceApprecation: displayBalanceApprecation,
                            accountRowViewModel: $0,
                            current: keystore.currentWallet)

                        return .wallet(viewModel)
                    }
                return .init(section: section, views: views)
            }
        }
    }

    private func canDeleteWallet(at indexPath: IndexPath) -> Bool {
        guard allowsAccountDeletion else { return false }
        let numberOfWallets: Int = viewModels.reduce(0) { $0 + $1.numberOfWallets }
        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            //We allow user to delete the last wallet. App store review wants users to be able to remove wallets
            return numberOfWallets == 1 || !viewModel.isSelected
        case .summary:
            return false
        }
    }

    //We don't show the section headers unless there are 2 "types" of wallets
    private func shouldHideAllSectionHeaders() -> Bool {
        let isKeystoreWalletsEmpty = sectionViewModel(for: .keystoreWallet)?.views.isEmpty ?? true
        let isWatchedWalletsEmpty = sectionViewModel(for: .watchedWallet)?.views.isEmpty ?? true
        let isHdWalletsEmpty = sectionViewModel(for: .hdWallet)?.views.isEmpty ?? true
        let isHardwareWalletsEmpty = sectionViewModel(for: .hardwareWallet)?.views.isEmpty ?? true

        if isKeystoreWalletsEmpty && isWatchedWalletsEmpty && isHardwareWalletsEmpty {
            return true
        }
        if isHdWalletsEmpty && isWatchedWalletsEmpty && isHardwareWalletsEmpty {
            return true
        }
        return false
    }

    private func sectionViewModel(for key: AccountsViewModel.Section) -> SectionViewModel? {
        viewModels.first(where: { $0.section == key })
    }

    private func indexPath(for wallet: Wallet) -> IndexPath? {
        return sections.enumerated().compactMap { (sectionIndex, section) -> IndexPath? in
            guard let row = sectionViewModel(for: section)?.views.firstIndex(where: {
                switch $0 {
                case .wallet(let viewModel):
                    return viewModel.wallet == wallet
                case .summary:
                    return false
                }
            }) else { return nil }

            return IndexPath(row: row, section: sectionIndex)
        }.first
    }

}

extension AccountsViewModel {
    class DataSource: UITableViewDiffableDataSource<AccountsViewModel.Section, AccountsViewModel.ViewModelType> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<AccountsViewModel.Section, AccountsViewModel.ViewModelType>

    enum SwipeAction {
        case copyToClipboard
        case deleteWallet

        var title: String {
            switch self {
            case .copyToClipboard: return R.string.localizable.copyAddress()
            case .deleteWallet: return R.string.localizable.accountsConfirmDeleteAction()
            }
        }

        var icon: UIImage? {
            switch self {
            case .copyToClipboard: return R.image.copy()?.withRenderingMode(.alwaysTemplate)
            case .deleteWallet: return R.image.close()?.withRenderingMode(.alwaysTemplate)
            }
        }

        var backgroundColor: UIColor {
            switch self {
            case .copyToClipboard: return Configuration.Color.Semantic.appTint
            case .deleteWallet: return Configuration.Color.Semantic.dangerBackground
            }
        }
    }

    enum ViewModelType {
        case wallet(AccountViewModel)
        case summary(WalletSummaryViewModel)

        var wallet: Wallet? {
            switch self {
            case .wallet(let vm): return vm.wallet
            case .summary: return nil
            }
        }
    }

    struct SectionViewModel {
        let section: Section
        let views: [ViewModelType]

        var numberOfWallets: Int {
            var results = 0
            for each in views {
                switch each {
                case .wallet:
                    results += 1
                case .summary:
                    break
                }
            }
            return results
        }
    }

    enum Section: Int, CaseIterable {
        case summary
        case hdWallet
        case keystoreWallet
        case hardwareWallet
        case watchedWallet

        var title: String {
            switch self {
            case .summary:
                return R.string.localizable.walletTypesSummary().uppercased()
            case .hdWallet:
                return R.string.localizable.walletTypesHdWallets().uppercased()
            case .keystoreWallet:
                return R.string.localizable.walletTypesKeystoreWallets().uppercased()
            case .hardwareWallet:
                return R.string.localizable.walletTypesHardwareWallets().uppercased()
            case .watchedWallet:
                return R.string.localizable.walletTypesWatchedWallets().uppercased()
            }
        }
    }

    struct AccountRowViewModel {
        let wallet: Wallet
        let blockie: BlockiesImage
        let addressOrEnsName: String
        let balance: WalletBalance
    }

    struct ViewState {
        let title: String
        let snapshot: AccountsViewModel.Snapshot
        let animatingDifferences: Bool = false
    }
}
extension AccountsViewModel.AccountRowViewModel: Hashable { }
extension AccountsViewModel.ViewModelType: Hashable { }
extension AccountsViewModel.SectionViewModel: Hashable { }
