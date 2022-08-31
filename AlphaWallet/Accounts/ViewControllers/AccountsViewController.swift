// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol AccountsViewControllerDelegate: AnyObject {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController)
    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController)
    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController)
    func didClose(in viewController: AccountsViewController)
}

class AccountsViewController: UIViewController {
    private var cancelable = Set<AnyCancellable>()
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()
    private let appear = PassthroughSubject<Void, Never>()
    private let _pullToRefresh = PassthroughSubject<Void, Never>()
    private let deleteWallet = PassthroughSubject<AccountsViewModel.WalletDeleteConfirmation, Never>()

    private let roundedBackground = RoundedBackground()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
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
        tableView.delegate = self
        tableView.dataSource = self
    } 

    private func bind(viewModel: AccountsViewModel) {
        let input = AccountsViewModelInput(
            appear: appear.eraseToAnyPublisher(),
            pullToRefresh: _pullToRefresh.eraseToAnyPublisher(),
            deleteWallet: deleteWallet.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState.sink { [weak self, weak tableView] state in
            self?.title = state.navigationTitle
            tableView?.reloadData()
        }.store(in: &cancelable)

        output.reloadBalanceState.sink { [weak refreshControl] state in
            switch state {
            case .fetching:
                refreshControl?.beginRefreshing()
            case .done, .failure:
                refreshControl?.endRefreshing()
            }
        }.store(in: &cancelable)

        output.deleteWalletState.sink { [weak self] data in
            guard let strongSelf = self else { return }
            switch data.state {
            case .willDelete:
                strongSelf.navigationController?.displayLoading(text: R.string.localizable.deleting())
            case .didDelete:
                strongSelf.navigationController?.hideLoading()
                strongSelf.delegate?.didDeleteAccount(account: data.wallet, in: strongSelf)
            case .none:
                break
            }
        }.store(in: &cancelable)

        output.askDeleteWalletConfirmation.sink { [weak self, deleteWallet] wallet in
            guard let strongSelf = self else { return }

            strongSelf.confirm(title: R.string.localizable.accountsConfirmDeleteTitle(),
                    message: R.string.localizable.accountsConfirmDeleteMessage(),
                    okTitle: R.string.localizable.accountsConfirmDeleteOkTitle(),
                    okStyle: .destructive) { result in
                switch result {
                case .success:
                    deleteWallet.send(.init(wallet: wallet, deleteConfirmed: true))
                case .failure:
                    deleteWallet.send(.init(wallet: wallet, deleteConfirmed: false))
                }
            }
        }.store(in: &cancelable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear.send(())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollCurrentWalletIntoView()
    }

    private func scrollCurrentWalletIntoView() {
        guard let indexPath = viewModel.activeWalletIndexPath else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }

    @objc private func pullToRefresh(_ sender: UIRefreshControl) {
        _pullToRefresh.send(())
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

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

extension AccountsViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
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
        return viewModel.trailingSwipeActionsConfiguration(for: indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let account = viewModel.account(for: indexPath) else { return }

        delegate?.didSelectAccount(account: account, in: self)
    }
}
