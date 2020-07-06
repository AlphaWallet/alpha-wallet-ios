// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import APIKit
import JSONRPCKit
import StatefulViewController
import Result

protocol TransactionsViewControllerDelegate: class {
    func didPressTransaction(transaction: Transaction, in viewController: TransactionsViewController)
}

class TransactionsViewController: UIViewController {
    private var viewModel: TransactionsViewModel
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let dataCoordinator: TransactionDataCoordinator
    private let sessions: ServerDictionary<WalletSession>

    var paymentType: PaymentFlow?
    weak var delegate: TransactionsViewControllerDelegate?

    init(
        dataCoordinator: TransactionDataCoordinator,
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
        tableView.estimatedRowHeight = TokensCardViewController.anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])

        dataCoordinator.delegate = self
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
        emptyView = {
            let view = TransactionsEmptyView()
            return view
        }()
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
        //Since this is called at launch, we don't want it to block launching
        DispatchQueue.global().async {
            DispatchQueue.main.async { [weak self] in
                self?.dataCoordinator.fetch()
            }
        }
    }

    func configure(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        if section == 0 {
            NSLayoutConstraint.activate([
                title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
            ])
        } else {
            NSLayoutConstraint.activate([
                title.anchorsConstraint(to: container, edgeInsets: .init(top: 4, left: 20, bottom: 16, right: 0))
            ])
        }
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
        delegate?.didPressTransaction(transaction: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
    }
}

extension TransactionsViewController: TransactionDataCoordinatorDelegate {
    func didUpdate(result: Result<[Transaction], TransactionError>) {
        switch result {
        case .success(let items):
        let viewModel = TransactionsViewModel(transactions: items)
            configure(viewModel: viewModel)
            endLoading()
        case .failure(let error):
            endLoading(error: error)
        }
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
        let transaction = viewModel.item(for: indexPath.row, section: indexPath.section)
        let cell: TransactionViewCell = tableView.dequeueReusableCell(for: indexPath)
        let session = sessions[transaction.server]
        cell.configure(viewModel: .init(
                transaction: transaction,
                chainState: session.chainState,
                currentWallet: session.account,
                server: transaction.server
            )
        )
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
}
