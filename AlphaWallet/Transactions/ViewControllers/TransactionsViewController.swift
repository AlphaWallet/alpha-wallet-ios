// Copyright © 2018 Stormbird PTE. LTD.

import UIKit 
import StatefulViewController
import AlphaWalletFoundation
import Combine

protocol TransactionsViewControllerDelegate: AnyObject {
    func didPressTransaction(transactionRow: TransactionRow, in viewController: TransactionsViewController)
}

class TransactionsViewController: UIViewController {
    private let viewModel: TransactionsViewModel
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(TransactionTableViewCell.self)
        tableView.registerHeaderFooterView(TransactionSectionHeaderView.self)
        tableView.delegate = self
        tableView.refreshControl = refreshControl

        return tableView
    }()
    private let refreshControl = UIRefreshControl()
    private lazy var dataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private var cancellable = Set<AnyCancellable>()

    weak var delegate: TransactionsViewControllerDelegate?

    init(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view),
        ])

        emptyView = EmptyView.transactionsEmptyView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    private func bind(viewModel: TransactionsViewModel) {
        let input = TransactionsViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            pullToRefresh: refreshControl.publisher(forEvent: .valueChanged).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self, dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading()
            }.store(in: &cancellable)

        output.pullToRefreshState
            .sink { [refreshControl] state in
                switch state {
                case .done, .failure: refreshControl.endRefreshing()
                case .loading: refreshControl.beginRefreshing()
                }
            }.store(in: &cancellable)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension TransactionsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension TransactionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        delegate?.didPressTransaction(transactionRow: dataSource.item(at: indexPath), in: self)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: TransactionSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.configure(title: dataSource.snapshot().sectionIdentifiers[section])

        return headerView
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}

extension TransactionsViewController {
    private func makeDataSource() -> TransactionsViewModel.DataSource {
        TransactionsViewModel.DataSource(tableView: tableView) { [viewModel] tableView, indexPath, transactionRow -> TransactionTableViewCell in
            let cell: TransactionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            guard let viewModel = viewModel.buildCellViewModel(for: transactionRow) else { return cell }
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
