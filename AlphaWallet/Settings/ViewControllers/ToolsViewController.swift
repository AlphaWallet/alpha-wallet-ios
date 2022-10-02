// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ToolsViewControllerDelegate: AnyObject {
    func consoleSelected(in controller: ToolsViewController)
    func pingInfuraSelected(in controller: ToolsViewController)
    func checkTransactionStateSelected(in controller: ToolsViewController)
}

class ToolsViewController: UIViewController {
    private let viewModel: ToolsViewModel
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = Configuration.Color.Semantic.tableViewSeparator
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    
    weak var delegate: ToolsViewControllerDelegate?

    init(viewModel: ToolsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure(viewModel: ToolsViewModel) {
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = viewModel.largeTitleDisplayMode
    }
}

extension ToolsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.viewModel(for: indexPath))

        return cell
    }
}

extension ToolsViewController: UITableViewDelegate {
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
        switch viewModel.row(for: indexPath) {
        case .console:
            delegate?.consoleSelected(in: self)
        case .pingInfura:
            delegate?.pingInfuraSelected(in: self)
        case .checkTransactionState:
            delegate?.checkTransactionStateSelected(in: self)
        }
    }
}
