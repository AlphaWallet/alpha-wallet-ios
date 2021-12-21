// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol AccountsViewControllerDelegate: AnyObject {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController)
    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController)
    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController)
}

class AccountsViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(AccountViewCell.self)
        tableView.register(WalletSummaryTableViewCell.self)
        tableView.addSubview(tableViewRefreshControl)
        return tableView
    }()
    private var viewModel: AccountsViewModel
    private let config: Config
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator
    weak var delegate: AccountsViewControllerDelegate?
    var allowsAccountDeletion: Bool = false
    var hasWallets: Bool {
        return !keystore.wallets.isEmpty
    }
    private let walletBalanceCoordinator: WalletBalanceCoordinatorType

    init(config: Config, keystore: Keystore, viewModel: AccountsViewModel, walletBalanceCoordinator: WalletBalanceCoordinatorType, analyticsCoordinator: AnalyticsCoordinator) {
        self.config = config
        self.keystore = keystore
        self.viewModel = viewModel
        self.walletBalanceCoordinator = walletBalanceCoordinator
        self.analyticsCoordinator = analyticsCoordinator
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate(
            tableView.anchorsConstraintSafeArea(to: roundedBackground) +
            roundedBackground.createConstraintsWithContainer(view: view)
        )
    }

    private lazy var tableViewRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configure(viewModel: .init(keystore: keystore, config: config, configuration: viewModel.configuration, analyticsCoordinator: analyticsCoordinator))
    }

    func configure(viewModel: AccountsViewModel) {
        self.viewModel = viewModel
        title = viewModel.title
        tableView.reloadData()
    }

    private func confirmDelete(account: Wallet) {
        confirm(
            title: R.string.localizable.accountsConfirmDeleteTitle(),
            message: R.string.localizable.accountsConfirmDeleteMessage(),
            okTitle: R.string.localizable.accountsConfirmDeleteOkTitle(),
            okStyle: .destructive
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                strongSelf.delete(account: account)
            case .failure: break
            }
        }
    }

    @objc private func pullToRefresh(_ sender: UIRefreshControl) {
        tableViewRefreshControl.beginRefreshing()
        walletBalanceCoordinator.refreshBalance(updatePolicy: .all, force: true).done { _ in
            // no-op
        }.cauterize().finally { [weak self] in
            self?.tableViewRefreshControl.endRefreshing()
        }
    }

    private func delete(account: Wallet) {
        navigationController?.displayLoading(text: R.string.localizable.deleting())
        let result = keystore.delete(wallet: account)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.navigationController?.hideLoading()

            switch result {
            case .success:
                strongSelf.configure(viewModel: .init(keystore: strongSelf.keystore, config: strongSelf.config, configuration: strongSelf.viewModel.configuration, analyticsCoordinator: strongSelf.analyticsCoordinator))
                strongSelf.delegate?.didDeleteAccount(account: account, in: strongSelf)
            case .failure(let error):
                strongSelf.displayError(error: error)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension AccountsViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(section: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .hdWallet, .keystoreWallet, .watchedWallet:
            let cell: AccountViewCell = tableView.dequeueReusableCell(for: indexPath)
            guard var cellViewModel = viewModel[indexPath] else {
                //NOTE: this should never happen here
                return UITableViewCell()
            }
            cell.configure(viewModel: cellViewModel)
            cell.account = cellViewModel.wallet

            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
            gesture.minimumPressDuration = 0.6
            cell.addGestureRecognizer(gesture)

            let address = cellViewModel.address
            ENSReverseLookupCoordinator(server: .forResolvingEns).getENSNameFromResolver(forAddress: address) { result in
                guard let ensName = result.value else { return }
                //Cell might have been reused. Check
                guard let cellAddress = cell.viewModel?.address, cellAddress.sameContract(as: address) else { return }
                cellViewModel.ensName = ensName
                cell.configure(viewModel: cellViewModel)
            }

            let subscribableBalance = walletBalanceCoordinator.subscribableWalletBalance(wallet: cellViewModel.wallet)
            if let key = cell.balanceSubscribtionKey {
                let subscription = subscribableBalance
                subscription.unsubscribe(key)
            }

            cell.balanceLabel.attributedText = cellViewModel.balanceAttributedString(for: subscribableBalance.value?.totalAmountString)
            cell.balanceSubscribtionKey = subscribableBalance.subscribe { [weak cell] balance in
                DispatchQueue.main.async {
                    guard let cell = cell, let cellAddress = cell.viewModel?.address, cellAddress.sameContract(as: address) else { return }

                    if self.viewModel.subscribeForBalanceUpdates {
                        cell.apprecation24hourLabel.attributedText = cellViewModel.apprecation24hourAttributedString(for: balance)
                    } else {
                        cell.apprecation24hourLabel.attributedText = .init()
                    }

                    cell.balanceLabel.attributedText = cellViewModel.balanceAttributedString(for: balance?.totalAmountString)
                }
            }

            return cell
        case .summary:
            let config = self.config
            let cell: WalletSummaryTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(summary: walletBalanceCoordinator.subscribableWalletsSummary.value, config: config))

            if let key = cell.walletSummarySubscriptionKey {
                walletBalanceCoordinator.subscribableWalletsSummary.unsubscribe(key)
            }

            cell.walletSummarySubscriptionKey = walletBalanceCoordinator.subscribableWalletsSummary.subscribe { summary in
                DispatchQueue.main.async {
                    cell.configure(viewModel: .init(summary: summary, config: config))
                }
            }

            return cell
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard allowsAccountDeletion else { return false }
        return viewModel.canEditCell(indexPath: indexPath)
    }

    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let cell = recognizer.view as? AccountViewCell, let account = cell.account, recognizer.state == .began else { return }

        delegate?.didSelectInfoForAccount(account: account, sender: cell, in: self)
    }
}

extension AccountsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.shouldHideHeader(in: section).shouldHide ? .leastNormalMagnitude : UITableView.automaticDimension
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let value = viewModel.shouldHideHeader(in: section)
        let headerView = AccountViewTableSectionHeader()
        headerView.configure(type: value.section, shouldHide: value.shouldHide)

        return headerView
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let copyAction = UIContextualAction(style: .normal, title: R.string.localizable.copyAddress()) { _, _, complete in
            guard let account = self.viewModel.account(for: indexPath) else { return }
            UIPasteboard.general.string = account.address.eip55String
            complete(true)
        }

        copyAction.image = R.image.copy()?.withRenderingMode(.alwaysTemplate)
        copyAction.backgroundColor = R.color.azure()

        let deleteAction = UIContextualAction(style: .normal, title: R.string.localizable.accountsConfirmDeleteAction()) { _, _, complete in
            guard let account = self.viewModel.account(for: indexPath) else { return }
            self.confirmDelete(account: account)

            complete(true)
        }

        deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
        deleteAction.backgroundColor = R.color.danger()

        let configuration = UISwipeActionsConfiguration(actions: [copyAction, deleteAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let account = viewModel.account(for: indexPath) else { return }

        delegate?.didSelectAccount(account: account, in: self)
    }
}
