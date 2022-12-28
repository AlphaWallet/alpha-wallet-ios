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
        return control
    }()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let deleteWallet = PassthroughSubject<AccountsViewModel.WalletDeleteConfirmation, Never>()

    private lazy var dataSource = makeDataSource()
    private lazy var tableView: UITableView = {
        let tableView = UITableView.grouped
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(AccountViewCell.self)
        tableView.register(WalletSummaryTableViewCell.self)
        tableView.refreshControl = refreshControl
        tableView.delegate = self

        return tableView
    }()

    let viewModel: AccountsViewModel
    weak var delegate: AccountsViewControllerDelegate?

    init(viewModel: AccountsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: AccountsViewModel) {
        let input = AccountsViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            pullToRefresh: refreshControl.publisher(forEvent: .valueChanged).eraseToAnyPublisher(),
            deleteWallet: deleteWallet.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [navigationItem, dataSource] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
            }.store(in: &cancelable)

        output.reloadBalanceState
            .sink { [refreshControl] state in
                switch state {
                case .fetching:
                    refreshControl.beginRefreshing()
                case .done, .failure:
                    refreshControl.endRefreshing()
                }
            }.store(in: &cancelable)

        output.deleteWalletState
            .sink { [weak self] data in
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

        output.askDeleteWalletConfirmation
            .sink { [weak self, deleteWallet] wallet in
                guard let strongSelf = self else { return }

                strongSelf.confirm(title: R.string.localizable.accountsConfirmDeleteTitle(),
                        message: R.string.localizable.accountsConfirmDeleteMessage(),
                        okTitle: R.string.localizable.accountsConfirmDeleteOkTitle(),
                        okStyle: .destructive) { result in
                    switch result {
                    case .success:
                        deleteWallet.send(.init(wallet: wallet, deletionConfirmed: true))
                    case .failure:
                        deleteWallet.send(.init(wallet: wallet, deletionConfirmed: false))
                    }
                }
            }.store(in: &cancelable)

        output.copiedToClipboard
            .sink(receiveValue: { [weak self] in
                self?.view.showCopiedToClipboard(title: $0)
            }).store(in: &cancelable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollCurrentWalletIntoView()
    }

    private func scrollCurrentWalletIntoView() {
        guard let indexPath = viewModel.activeWalletIndexPath else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func addLongPressGestureRecognizer(toView view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
        gesture.minimumPressDuration = 0.6
        view.addGestureRecognizer(gesture)
    }

    @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let cell = recognizer.view as? AccountViewCell, let indexPath = cell.indexPath, recognizer.state == .began else { return }
        
        switch dataSource.item(at: indexPath) {
        case .wallet(let viewModel):
            delegate?.didSelectInfoForAccount(account: viewModel.wallet, sender: cell, in: self)
        case .undefined, .summary:
            break
        }
    }
}

extension AccountsViewController {
    private func makeDataSource() -> AccountsViewModel.DataSource {
        AccountsViewModel.DataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, viewModel in
            guard let strongSelf = self else { return UITableViewCell() }

            switch viewModel {
            case .undefined:
                return UITableViewCell()
            case .wallet(let viewModel):
                let cell: AccountViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                strongSelf.addLongPressGestureRecognizer(toView: cell)

                return cell
            case .summary(let viewModel):
                let cell: WalletSummaryTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            }
        })
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

        switch dataSource.item(at: indexPath) {
        case .wallet(let viewModel):
            delegate?.didSelectAccount(account: viewModel.wallet, in: self)
        case .summary, .undefined:
            break
        }
    }
}

extension UITableViewDiffableDataSource {
    func item(at indexPath: IndexPath) -> ItemIdentifierType {
        let snapshot = snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        return snapshot.itemIdentifiers(inSection: section)[indexPath.row]
    }
}

extension UICollectionViewDiffableDataSource {
    func item(at indexPath: IndexPath) -> ItemIdentifierType {
        let snapshot = snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        return snapshot.itemIdentifiers(inSection: section)[indexPath.row]
    }
}
