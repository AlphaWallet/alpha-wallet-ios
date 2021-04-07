// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol EnabledServersViewControllerDelegate: class {
    func didSelectServers(servers: [RPCServer], in viewController: EnabledServersViewController)
}

class EnabledServersViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(ServerViewCell.self)
        tableView.dataSource = self

        return tableView
    }()
    private var viewModel: EnabledServersViewModel

    weak var delegate: EnabledServersViewControllerDelegate?

    init(viewModel: EnabledServersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = GroupedTable.Color.background

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure(viewModel: viewModel)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            done()
        } else {
            //no-op
        }
    }

    func configure(viewModel: EnabledServersViewModel) {
        self.viewModel = viewModel
        title = viewModel.title
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func done() {
        delegate?.didSelectServers(servers: viewModel.selectedServers, in: self)
    }
}

extension EnabledServersViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.servers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ServerViewCell = tableView.dequeueReusableCell(for: indexPath)
        let server = viewModel.server(for: indexPath)
        let cellViewModel = ServerViewModel(server: server, selected: viewModel.isServerSelected(server))
        cell.configure(viewModel: cellViewModel)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let server = viewModel.server(for: indexPath)
        let servers: [RPCServer]
        if viewModel.selectedServers.contains(server) {
            servers = viewModel.selectedServers - [server]
        } else {
            servers = viewModel.selectedServers + [server]
        }
        configure(viewModel: .init(servers: viewModel.servers, selectedServers: servers))
        tableView.reloadData()
        //Even if no servers is selected, we don't attempt to disable the back button here since calling code will take care of ignore the change server "request" when there are no servers selected. We don't want to disable the back button because users can't cancel the operation
    }
}
