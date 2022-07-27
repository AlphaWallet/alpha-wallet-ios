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
    private var cancelable = Set<AnyCancellable>()
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()
    private let roundedBackground = RoundedBackground()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(AccountViewCell.self)
        tableView.register(WalletSummaryTableViewCell.self)
        tableView.addSubview(refreshControl)
        return tableView
    }()

    let viewModel: AccountsViewModel
    weak var delegate: AccountsViewControllerDelegate?

    init(viewModel: AccountsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = viewModel.backgroundColor
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate(
            tableView.anchorsConstraintSafeArea(to: roundedBackground) +
            roundedBackground.createConstraintsWithContainer(view: view)
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)
    } 

    private func bind(viewModel: AccountsViewModel) {
        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak tableView] _ in
                tableView?.reloadData()
            }.store(in: &cancelable)

        viewModel.reloadBalancePublisher
            .receive(on: RunLoop.main)
            .sink { [weak refreshControl] state in
                switch state {
                case .fetching:
                    refreshControl?.beginRefreshing()
                case .done, .failure:
                    refreshControl?.endRefreshing()
                }
            }.store(in: &cancelable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollCurrentWalletIntoView()
    }

    private func scrollCurrentWalletIntoView() {
        guard let indexPath = viewModel.activeWalletIndexPath else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }

    private func reload() {
        viewModel.reload()
        title = viewModel.title
        tableView.reloadData()
    }

    private func confirmDelete(account: Wallet, complete: @escaping (Bool) -> Void) {
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
                complete(true)
            case .failure:
                complete(false)
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
                self?.reload()
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
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(section: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.viewModel(at: indexPath) {
        case .undefined:
            return UITableViewCell()
        case .wallet(let viewModel):
            let cell: AccountViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(viewModel: viewModel)

            addLongPressGestureRecognizer(toView: cell)

            return cell
        case .summary(let viewModel):
            let cell: WalletSummaryTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }

    private func addLongPressGestureRecognizer(toView view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
        gesture.minimumPressDuration = 0.6
        view.addGestureRecognizer(gesture)
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
        return viewModel.heightForHeader(in: section)
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
        var actions: [UIContextualAction] = []

        let copyAction = UIContextualAction(style: .normal, title: R.string.localizable.copyAddress()) { _, _, complete in
            guard let account = self.viewModel.account(for: indexPath) else { return }
            UIPasteboard.general.string = account.address.eip55String
            self.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
            complete(true)
        }
        copyAction.image = R.image.copy()?.withRenderingMode(.alwaysTemplate)
        copyAction.backgroundColor = R.color.azure()

        actions += [copyAction]

        if viewModel.canDeleteWallet(at: indexPath) {
            let deleteAction = UIContextualAction(style: .normal, title: R.string.localizable.accountsConfirmDeleteAction()) { _, _, complete in
                guard let account = self.viewModel.account(for: indexPath) else { return }
                self.confirmDelete(account: account, complete: complete)
            }

            deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
            deleteAction.backgroundColor = R.color.danger()

            actions += [deleteAction]
        }

        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let account = viewModel.account(for: indexPath) else { return }

        delegate?.didSelectAccount(account: account, in: self)
    }
}
