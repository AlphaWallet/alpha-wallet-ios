// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine
import UIKit
import AlphaWalletFoundation
import CombineExt

struct AccountsViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
    let deleteWallet: AnyPublisher<AccountsViewModel.WalletDeleteConfirmation, Never>
}

struct AccountsViewModelOutput {
    let viewState: AnyPublisher<AccountsViewModel.ViewState, Never>
    let reloadBalanceState: AnyPublisher<AccountsViewModel.ReloadState, Never>
    let deleteWalletState: AnyPublisher<(wallet: Wallet, state: AccountsViewModel.DeleteWalletState), Never>
    let askDeleteWalletConfirmation: AnyPublisher<Wallet, Never>
    let copiedToClipboard: AnyPublisher<String, Never>
}

final class AccountsViewModel {
    private var config: Config
    private var viewModels: [AccountsViewModel.SectionViewModel] = []
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let walletBalanceService: WalletBalanceService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    private var reloadBalanceSubject: PassthroughSubject<ReloadState, Never> = .init()
    private var deleteWalletState: PassthroughSubject<AccountsViewModel.DeleteWalletState, Never> = .init()
    private var askDeleteWalletConfirmation: PassthroughSubject<Wallet, Never> = .init()
    private var copiedToClipboard: PassthroughSubject<String, Never> = .init()

    private lazy var getWalletName = GetWalletName(domainResolutionService: domainResolutionService)
    private var sections: [AccountsViewModel.Section] {
        switch configuration {
        case .changeWallets:
            return [.hdWallet, .keystoreWallet, .watchedWallet]
        case .summary:
            return [.summary, .hdWallet, .keystoreWallet, .watchedWallet]
        }
    }
    private var deleteWalletPendingBlock: ((Bool) -> Void)?

    let configuration: AccountsCoordinatorViewModel.Configuration
    var allowsAccountDeletion: Bool = false
    var displayBalanceApprecation: Bool {
        switch configuration {
        case .changeWallets:
            return false
        case .summary:
            return !Config().enabledServers.allSatisfy { $0.isTestnet }
        }
    }

    var activeWalletIndexPath: IndexPath? {
        keystore.currentWallet.flatMap { indexPath(for: $0) }
    }

    var hasWallets: Bool {
        return keystore.hasWallets
    }

    init(keystore: Keystore, config: Config, configuration: AccountsCoordinatorViewModel.Configuration, analytics: AnalyticsLogger, walletBalanceService: WalletBalanceService, blockiesGenerator: BlockiesGenerator, domainResolutionService: DomainResolutionServiceType) {
        self.config = config
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
        let deleteWallet = input.deleteWallet
            .flatMap { [weak self, deleteWalletState] confirmation -> AnyPublisher<(wallet: Wallet, state: AccountsViewModel.DeleteWalletState), Never> in
                self?.fulfillPendingDeleteConfirmationBlock(confirmation.deletionConfirmed)
                if confirmation.deletionConfirmed {
                    self?.delete(account: confirmation.wallet)
                    return deleteWalletState.map { (wallet: confirmation.wallet, state: $0) }.eraseToAnyPublisher()
                } else {
                    return .just((confirmation.wallet, .none))
                }
            }

        let reloadBalance = input.pullToRefresh
            .handleEvents(receiveOutput: { [weak self] _ in self?.reloadBalance() })

        let reloadWhenDelated = deleteWalletState.filter { $0 == .didDelete }
            .receive(on: DispatchQueue.main)
            .mapToVoid()

        let accountRowViewModels = Publishers.Merge3(input.willAppear, reloadWhenDelated, reloadBalance)
            .map { [keystore] _ in keystore.wallets }
            .map { $0.map { self.buildAccountRowViewModel(wallet: $0) } }
            .flatMapLatest { $0.combineLatest() }

        let walletsSummary = input.willAppear
            .flatMap { [walletBalanceService] _ in walletBalanceService.walletsSummary }
            .map { [config] in WalletSummaryViewModel(walletSummary: $0, config: config) }

        let viewModels = Publishers.CombineLatest(accountRowViewModels, walletsSummary)
            .map { self.buildViewModels(sections: self.sections, accountViewModels: $0, summary: $1) }
            .handleEvents(receiveOutput: { self.viewModels = $0 })

        let viewState = viewModels
            .map { self.buildSnapshot(for: $0) }
            .map { [configuration] snapshot in AccountsViewModel.ViewState(title: configuration.title, snapshot: snapshot) }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            reloadBalanceState: reloadBalanceSubject.eraseToAnyPublisher(),
            deleteWalletState: deleteWallet.eraseToAnyPublisher(),
            askDeleteWalletConfirmation: askDeleteWalletConfirmation.eraseToAnyPublisher(),
            copiedToClipboard: copiedToClipboard.eraseToAnyPublisher())
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
            .handleEvents(receiveOutput: { [weak self] value in
                guard value.isEnsAvatar else { return }
                self?.analytics.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
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

    func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var actions: [UIContextualAction] = []
        let copyAction = UIContextualAction(style: .normal, title: R.string.localizable.copyAddress()) { [weak self, copiedToClipboard] _, _, complete in
            guard let account = self?.account(for: indexPath) else { return }
            UIPasteboard.general.string = account.address.eip55String
            copiedToClipboard.send(R.string.localizable.copiedToClipboard())

            complete(true)
        }
        copyAction.image = R.image.copy()?.withRenderingMode(.alwaysTemplate)
        copyAction.backgroundColor = Colors.appTint

        actions += [copyAction]

        if canDeleteWallet(at: indexPath) {
            let deleteAction = UIContextualAction(style: .normal, title: R.string.localizable.accountsConfirmDeleteAction()) { [weak self, askDeleteWalletConfirmation] _, _, complete in
                guard let account = self?.account(for: indexPath) else { return }
                askDeleteWalletConfirmation.send(account)
                self?.deleteWalletPendingBlock = complete
            }

            deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
            deleteAction.backgroundColor = Colors.appRed

            actions += [deleteAction]
        }

        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func account(for indexPath: IndexPath) -> Wallet? {
        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            return viewModel.wallet
        case .summary, .undefined:
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
        case .summary:
            return (shouldHide: false, section: .summary)
        }
    }

    private func reloadBalance() {
        reloadBalanceSubject.send(.fetching)
        walletBalanceService.refreshBalance(updatePolicy: .all, wallets: keystore.wallets)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [reloadBalanceSubject] in
            reloadBalanceSubject.send(.done)
        }
    }

    private func fulfillPendingDeleteConfirmationBlock(_ value: Bool) {
        deleteWalletPendingBlock?(value)
        deleteWalletPendingBlock = nil
    }

    private func buildViewModels(sections: [Section], accountViewModels: [AccountRowViewModel], summary: WalletSummaryViewModel) -> [SectionViewModel] {
        sections.map { section in
            switch section {
            case .summary:
                return .init(section: section, views: [.summary(summary)])
            case .hdWallet:
                let hdWallets = accountViewModels.filter { $0.wallet.origin == .hd }.sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                let views: [ViewModelType] = hdWallets.map {
                    let viewModel = AccountViewModel(displayBalanceApprecation: displayBalanceApprecation, accountRowViewModel: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            case .keystoreWallet:
                let keystoreWallets = accountViewModels.filter { $0.wallet.origin == .privateKey }.sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                let views: [ViewModelType] = keystoreWallets.map {
                    let viewModel = AccountViewModel(displayBalanceApprecation: displayBalanceApprecation, accountRowViewModel: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            case .watchedWallet:
                let watchedWallets = accountViewModels.filter { $0.wallet.origin == .watch }.sorted { $0.wallet.address.eip55String < $1.wallet.address.eip55String }
                let views: [ViewModelType] = watchedWallets.map {
                    let viewModel = AccountViewModel(displayBalanceApprecation: displayBalanceApprecation, accountRowViewModel: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            }
        }
    }

    private func delete(account: Wallet) {
        deleteWalletState.send(.willDelete)
        let _ = keystore.delete(wallet: account)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [deleteWalletState] in
            deleteWalletState.send(.didDelete)
        }
    }

    private func canDeleteWallet(at indexPath: IndexPath) -> Bool {
        guard allowsAccountDeletion else { return false }
        let numberOfWallets: Int = viewModels.reduce(0) { $0 + $1.numberOfWallets }
        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            //We allow user to delete the last wallet. App store review wants users to be able to remove wallets
            return numberOfWallets == 1 || !viewModel.isSelected
        case .summary, .undefined:
            return false
        }
    }

    //We don't show the section headers unless there are 2 "types" of wallets
    private func shouldHideAllSectionHeaders() -> Bool {
        let isKeystoreWalletsEmpty = sectionViewModel(for: .keystoreWallet)?.views.isEmpty ?? true
        let isWatchedWalletsEmpty = sectionViewModel(for: .watchedWallet)?.views.isEmpty ?? true
        let isHdWalletsEmpty = sectionViewModel(for: .hdWallet)?.views.isEmpty ?? true

        if isKeystoreWalletsEmpty && isWatchedWalletsEmpty {
            return true
        }
        if isHdWalletsEmpty && isWatchedWalletsEmpty {
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
                case .undefined, .summary:
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

    struct WalletDeleteConfirmation {
        let wallet: Wallet
        let deletionConfirmed: Bool
    }

    enum ViewModelType {
        case wallet(AccountViewModel)
        case summary(WalletSummaryViewModel)
        case undefined
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
                case .summary, .undefined:
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

    struct AccountRowViewModel {
        let wallet: Wallet
        let blockie: BlockiesImage
        let addressOrEnsName: String
        let balance: WalletBalance
    }

    enum ReloadState {
        case fetching
        case done
        case failure(error: Error)
    }

    enum DeleteWalletState {
        case willDelete
        case didDelete
        case none
    }

    struct ViewState {
        let title: String
        let snapshot: AccountsViewModel.Snapshot
        let animatingDifferences: Bool = false
    }
}
extension AccountsViewModel.AccountRowViewModel: Hashable { }
extension AccountsViewModel.ViewModelType: Hashable { }
