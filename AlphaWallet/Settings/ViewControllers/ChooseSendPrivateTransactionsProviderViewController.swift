// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ChooseSendPrivateTransactionsProviderViewControllerDelegate: AnyObject {
    func privateTransactionProviderSelected(provider: SendPrivateTransactionsProvider?, inController viewController: ChooseSendPrivateTransactionsProviderViewController)
}

class ChooseSendPrivateTransactionsProviderViewController: UIViewController {
    private lazy var viewModel = ChooseSendPrivateTransactionsProviderViewModel()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.register(SelectionTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private let roundedBackground = RoundedBackground()
    private var config: Config
    weak var delegate: ChooseSendPrivateTransactionsProviderViewControllerDelegate?

    init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle()
        navigationItem.largeTitleDisplayMode = .never
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
        let row = viewModel.rows[indexPath.row]
        let cell: SelectionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: .init(titleText: row.title, icon: row.icon, value: config.sendPrivateTransactionsProvider == row))
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
        let provider = viewModel.rows[indexPath.row]
        let chosenProvider: SendPrivateTransactionsProvider?
        if provider == config.sendPrivateTransactionsProvider {
            chosenProvider = nil
        } else {
            chosenProvider = provider
        }
        config.sendPrivateTransactionsProvider = chosenProvider
        tableView.reloadData()
        delegate?.privateTransactionProviderSelected(provider: chosenProvider, inController: self)
    }
}
