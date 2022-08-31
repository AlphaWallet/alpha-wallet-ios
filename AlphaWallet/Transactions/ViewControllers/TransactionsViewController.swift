// Copyright © 2018 Stormbird PTE. LTD.

import UIKit 
import StatefulViewController
import AlphaWalletFoundation

protocol TransactionsViewControllerDelegate: AnyObject {
    func didPressTransaction(transactionRow: TransactionRow, in viewController: TransactionsViewController)
}

class TransactionsViewController: UIViewController {
    private var viewModel: TransactionsViewModel
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let dataCoordinator: TransactionsService
    private let sessions: ServerDictionary<WalletSession>

    weak var delegate: TransactionsViewControllerDelegate?

    init(
        dataCoordinator: TransactionsService,
        sessions: ServerDictionary<WalletSession>,
        viewModel: TransactionsViewModel
    ) {
        self.dataCoordinator = dataCoordinator
        self.sessions = sessions
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.transactionsTabbarItemTitle()

        view.backgroundColor = self.viewModel.backgroundColor

        tableView.register(TransactionViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.estimatedRowHeight = Metrics.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])

        dataCoordinator.start()

        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(refreshControl)

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.dataCoordinator.fetch()
        })
        loadingView = LoadingView()
        //TODO move into StateViewModel once this change is global
        if let loadingView = loadingView as? LoadingView {
            loadingView.backgroundColor = Colors.appGrayLabel
            loadingView.label.textColor = Colors.appWhite
            loadingView.loadingIndicator.color = Colors.appWhite
            loadingView.label.font = Fonts.regular(size: 18)
        }
        emptyView = EmptyView.transactionsEmptyView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetch()
    }

    @objc func pullToRefresh() {
        refreshControl.beginRefreshing()
        fetch()
    }

    func fetch() {
        startLoading()
        dataCoordinator.fetch()
    }

    func configure(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
        
        self.endLoading()
        self.reloadTableViewAndEndRefreshing()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    fileprivate func headerView(for section: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = viewModel.headerBackgroundColor
        let title = UILabel()
        title.text = viewModel.titleForHeader(in: section)
        title.sizeToFit()
        title.textColor = viewModel.headerTitleTextColor
        title.font = viewModel.headerTitleFont
        container.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
        ])
        return container
    }
}

extension TransactionsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections > 0
    }
}

extension TransactionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true )
        delegate?.didPressTransaction(transactionRow: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
    }

    private func reloadTableViewAndEndRefreshing() {
        tableView.reloadData()

        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }
}

extension TransactionsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let transactionRow = viewModel.item(for: indexPath.row, section: indexPath.section)
        let cell: TransactionViewCell = tableView.dequeueReusableCell(for: indexPath)
        let session = sessions[transactionRow.server]
        let viewModel: TransactionRowCellViewModel = .init(transactionRow: transactionRow, chainState: session.chainState, wallet: session.account, server: transactionRow.server)
        cell.configure(viewModel: viewModel)

        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView(for: section)
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}
