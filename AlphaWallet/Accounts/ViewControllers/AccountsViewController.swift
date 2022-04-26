// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import Combine

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
    let viewModel: AccountsViewModel
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: AccountsViewControllerDelegate?

    init(viewModel: AccountsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate(
            tableView.anchorsConstraintSafeArea(to: roundedBackground) +
            roundedBackground.createConstraintsWithContainer(view: view)
        )
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.reloadBalancePublisher
            .receive(on: RunLoop.main)
            .sink { [weak tableViewRefreshControl] state in
                switch state {
                case .fetching:
                    tableViewRefreshControl?.beginRefreshing()
                case .done, .failure:
                    tableViewRefreshControl?.endRefreshing()
                }
            }.store(in: &cancelable)
    }

    private lazy var tableViewRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configure()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollCurrentWalletIntoView()
    }

    private func scrollCurrentWalletIntoView() {
        guard let indexPath = viewModel.activeWalletIndexPath else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }

    func configure() {
        viewModel.reloadWallets()
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
        viewModel.reloadBalance()
    }

    private func delete(account: Wallet) {
        navigationController?.displayLoading(text: R.string.localizable.deleting())
        let result = viewModel.delete(account: account)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.navigationController?.hideLoading()

            switch result {
            case .success:
                self?.configure()
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

// MARK: - TableView Data Source

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
            guard let viewModel = viewModel.accountViewModel(forIndexPath: indexPath) else { return UITableViewCell() }

            let cell: AccountViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            addLongPressGestureRecognizer(toView: cell)

            return cell
        case .summary:
            let cell: WalletSummaryTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel.walletSummaryViewModel)

            return cell
        }
    }

    private func addLongPressGestureRecognizer(toView view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
        gesture.minimumPressDuration = 0.6
        view.addGestureRecognizer(gesture)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel.canEditCell(indexPath: indexPath)
    }

    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let cell = recognizer.view as? AccountViewCell, let indexPath = cell.indexPath, recognizer.state == .began else { return }
        guard let account = viewModel.account(for: indexPath) else { return }

        delegate?.didSelectInfoForAccount(account: account, sender: cell, in: self)
    }
}

// MARK: - TableView Delegate

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
