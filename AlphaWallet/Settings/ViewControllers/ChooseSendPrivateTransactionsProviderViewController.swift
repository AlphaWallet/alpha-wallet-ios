// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import Combine

class ChooseSendPrivateTransactionsProviderViewController: UIViewController {
    private let viewModel: ChooseSendPrivateTransactionsProviderViewModel
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.register(SelectionTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = Configuration.Color.Semantic.tableViewSeparator
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground

        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private lazy var dataSource: ChooseSendPrivateTransactionsProviderViewModel.DataSource = makeDataSource()
    private let appear = PassthroughSubject<Void, Never>()
    private let disappear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private var cancelable = Set<AnyCancellable>()

    init(viewModel: ChooseSendPrivateTransactionsProviderViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear.send(())
    }

    private func bind(viewModel: ChooseSendPrivateTransactionsProviderViewModel) {
        let input = ChooseSendPrivateTransactionsProviderViewModelInput(appear: appear.eraseToAnyPublisher(), selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [dataSource, navigationItem] state in
                navigationItem.title = state.title
                navigationItem.largeTitleDisplayMode = state.largeTitleDisplayMode
                dataSource.apply(state.snapshot, animatingDifferences: false)
            }.store(in: &cancelable)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ChooseSendPrivateTransactionsProviderViewController {
    private func makeDataSource() -> ChooseSendPrivateTransactionsProviderViewModel.DataSource {
        ChooseSendPrivateTransactionsProviderViewModel.DataSource(tableView: tableView) { tableView, indexPath, viewModel -> SelectionTableViewCell in
            let cell: SelectionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}

extension ChooseSendPrivateTransactionsProviderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selection.send(indexPath)
    }
}
