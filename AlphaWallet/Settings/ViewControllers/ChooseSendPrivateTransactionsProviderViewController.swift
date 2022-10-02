// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

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
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

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

    private func bind(viewModel: ChooseSendPrivateTransactionsProviderViewModel) {
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = viewModel.largeTitleDisplayMode
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ChooseSendPrivateTransactionsProviderViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SelectionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.viewModel(for: indexPath))
        
        return cell
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
        viewModel.selectProvider(at: indexPath)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
