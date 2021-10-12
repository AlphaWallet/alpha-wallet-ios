// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ServersViewControllerDelegate: AnyObject {
    func didSelectServer(server: RPCServerOrAuto, in viewController: ServersViewController)
}

class ServersViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(ServerTableViewCell.self)
        
        return tableView
    }()
    private var viewModel: ServersViewModel
    private let roundedBackground = RoundedBackground()
    weak var delegate: ServersViewControllerDelegate?

    init(viewModel: ServersViewModel) {
        self.viewModel = viewModel
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
        configure(viewModel: viewModel)
    }

    func configure(viewModel: ServersViewModel) {
        self.viewModel = viewModel
        navigationItem.title = viewModel.title
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ServersViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.servers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ServerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let server = viewModel.server(for: indexPath)
        let cellViewModel = ServerViewModel(server: server, selected: viewModel.isServerSelected(server))
        cell.configure(viewModel: cellViewModel)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let server = viewModel.server(for: indexPath)
        delegate?.didSelectServer(server: server, in: self)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard viewModel.displayWarningFooter else {
            return nil
        }

        let footer = UIView()
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = viewModel.descriptionColor
        label.text = viewModel.descriptionText
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: footer, edgeInsets: .init(top: 7, left: 20, bottom: 0, right: 20))
        ])

        return footer
    }
}
