// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine 
import UIKit
import AlphaWalletFoundation

struct AccountsViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
    let deleteWallet: AnyPublisher<AccountsViewModel.WalletDeleteConfirmation, Never>
}

struct AccountsViewModelOutput {
    let viewState: AnyPublisher<AccountsViewModel.ViewState, Never>
    let reloadBalanceState: AnyPublisher<AccountsViewModel.ReloadState, Never>
    let deleteWalletState: AnyPublisher<(wallet: Wallet, state: AccountsViewModel.DeleteWalletState), Never>
    let askDeleteWalletConfirmation: AnyPublisher<Wallet, Never>
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
    private var reloadSubject: PassthroughSubject<Void, Never> = .init()
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

    var hasWallets: Bool {
        return keystore.hasWallets
    }

    var navigationTitle: String {
        return configuration.navigationTitle
    }

    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewBackground

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
                self?.fulfillPendingDeleteConfirmationBlock(confirmation.deleteConfirmed)
                if confirmation.deleteConfirmed {
                    self?.delete(account: confirmation.wallet)
                    return deleteWalletState.map { (wallet: confirmation.wallet, state: $0) }.eraseToAnyPublisher()
                } else {
                    return .just((confirmation.wallet, .none))
                }
            }

        let reloadBalance = input.pullToRefresh
            .handleEvents(receiveOutput: { [weak self] _ in self?.reloadBalance() })

        let appearOrUpdate = Publishers.Merge4(Just<Void>(()), input.appear.receive(on: DispatchQueue.main), reloadSubject.receive(on: DispatchQueue.main), reloadBalance)
        let sections: AnyPublisher<[AccountsViewModel.Section], Never> = appearOrUpdate.map { _ in self.sections }.eraseToAnyPublisher()

        let walletsSummary = walletBalanceService.walletsSummary.map { [config] in WalletSummaryViewModel(walletSummary: $0, config: config) }
        //NOTE: Make state hashable, to apply diffable data source
        let viewState = Publishers.CombineLatest(sections, walletsSummary)
            .map { self.buildViewModels(sections: $0, summary: $1) }
            .handleEvents(receiveOutput: { viewModels in
                self.viewModels = viewModels
            })
            .map { [configuration] sections in AccountsViewModel.ViewState(navigationTitle: configuration.navigationTitle, sections: sections) }
            .eraseToAnyPublisher()

        return .init(
            viewState: viewState,
            reloadBalanceState: reloadBalanceSubject.eraseToAnyPublisher(),
            deleteWalletState: deleteWallet.eraseToAnyPublisher(),
            askDeleteWalletConfirmation: askDeleteWalletConfirmation.eraseToAnyPublisher())
    }

    func set(name: String, for wallet: Wallet) {
        //TODO: pass ref
        FileWalletStorage().addOrUpdate(name: name, for: wallet.address)
        reloadSubject.send(())
    }

    func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var actions: [UIContextualAction] = []
        let copyAction = UIContextualAction(style: .normal, title: R.string.localizable.copyAddress()) { [weak self] _, _, complete in
            guard let account = self?.account(for: indexPath) else { return }
            UIPasteboard.general.string = account.address.eip55String
            complete(true)
        }
        copyAction.image = R.image.copy()?.withRenderingMode(.alwaysTemplate)
        copyAction.backgroundColor = R.color.azure()

        actions += [copyAction]

        if canDeleteWallet(at: indexPath) {
            let deleteAction = UIContextualAction(style: .normal, title: R.string.localizable.accountsConfirmDeleteAction()) { [weak self, askDeleteWalletConfirmation] _, _, complete in
                guard let account = self?.account(for: indexPath) else { return }
                askDeleteWalletConfirmation.send(account)
                self?.deleteWalletPendingBlock = complete
            }

            deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
            deleteAction.backgroundColor = R.color.danger()

            actions += [deleteAction]
        }
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func assignedNameOrEns(for wallet: Wallet) -> AnyPublisher<String?, Never> {
        return getWalletName.assignedNameOrEns(for: wallet.address)
    }

    func resolvedEns(for wallet: Wallet) -> AnyPublisher<String?, Never> {
        domainResolutionService.resolveEns(address: wallet.address)
            .map { ens -> EnsName? in return ens }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    func assignedName(for wallet: Wallet) -> AnyPublisher<String?, Never> {
        let walletName = FileWalletStorage().name(for: wallet.address)
        return .just(walletName)
    }

    func account(for indexPath: IndexPath) -> Wallet? {
        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            return viewModel.wallet
        case .summary, .undefined:
            return .none
        }
    }

    func viewModel(at indexPath: IndexPath) -> ViewModelType {
        return viewModels[indexPath.section].views[indexPath.row]
    }

    func numberOfItems(section: Int) -> Int {
        return viewModels[section].views.count
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

    private func buildViewModels(sections: [Section], summary: WalletSummaryViewModel) -> [SectionViewModel] {
        sections.map { section in
            switch section {
            case .summary:
                return .init(section: section, views: [.summary(summary)])
            case .hdWallet:
                let hdWallets = keystore.wallets.filter { $0.origin == .hd }.sorted { $0.address.eip55String < $1.address.eip55String }
                let views: [ViewModelType] = hdWallets.map {
                    let viewModel = AccountViewModel(analytics: analytics, getWalletName: getWalletName, blockiesGenerator: blockiesGenerator, subscribeForBalanceUpdates: subscribeForBalanceUpdates, walletBalanceService: walletBalanceService, wallet: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            case .keystoreWallet:
                let keystoreWallets = keystore.wallets.filter { $0.origin == .privateKey }.sorted { $0.address.eip55String < $1.address.eip55String }
                let views: [ViewModelType] = keystoreWallets.map {
                    let viewModel = AccountViewModel(analytics: analytics, getWalletName: getWalletName, blockiesGenerator: blockiesGenerator, subscribeForBalanceUpdates: subscribeForBalanceUpdates, walletBalanceService: walletBalanceService, wallet: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            case .watchedWallet:
                let watchedWallets = keystore.wallets.filter { $0.origin == .watch }.sorted { $0.address.eip55String < $1.address.eip55String }
                let views: [ViewModelType] = watchedWallets.map {
                    let viewModel = AccountViewModel(analytics: analytics, getWalletName: getWalletName, blockiesGenerator: blockiesGenerator, subscribeForBalanceUpdates: subscribeForBalanceUpdates, walletBalanceService: walletBalanceService, wallet: $0, current: keystore.currentWallet)

                    return .wallet(viewModel)
                }
                return .init(section: section, views: views)
            }
        }
    }

    private func delete(account: Wallet) {
        deleteWalletState.send(.willDelete)
        let _ = keystore.delete(wallet: account)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [deleteWalletState, reloadSubject] in
            deleteWalletState.send(.didDelete)
            reloadSubject.send(())
        }
    }

    private func canDeleteWallet(at indexPath: IndexPath) -> Bool {
        guard allowsAccountDeletion else { return false }

        switch viewModels[indexPath.section].views[indexPath.row] {
        case .wallet(let viewModel):
            return viewModel.canEditCell
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
    struct WalletDeleteConfirmation {
        let wallet: Wallet
        let deleteConfirmed: Bool
    }

    enum ViewModelType {
        case wallet(AccountViewModel)
        case summary(WalletSummaryViewModel)
        case undefined
    }

    struct SectionViewModel {
        let section: Section
        let views: [ViewModelType]
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

    enum DeleteWalletState {
        case willDelete
        case didDelete
        case none
    }

    struct ViewState {
        let navigationTitle: String
        let sections: [AccountsViewModel.SectionViewModel]
    }

}
