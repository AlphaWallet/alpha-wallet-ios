// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ServersViewControllerDelegate: class {
    func didSelectServer(server: RPCServerOrAuto, in viewController: ServersViewController)
}

class ServersViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var viewModel: ServersViewModel?

    weak var delegate: ServersViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = GroupedTable.Color.background

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(ServerViewCell.self, forCellReuseIdentifier: ServerViewCell.identifier)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    func configure(viewModel: ServersViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self
        title = viewModel.title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ServersViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.servers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ServerViewCell.identifier, for: indexPath) as! ServerViewCell
        if let viewModel = viewModel {
            let server = viewModel.server(for: indexPath)
            let cellViewModel = ServerViewModel(server: server, selected: viewModel.isServerSelected(server))
            cell.configure(viewModel: cellViewModel)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let viewModel = viewModel else { return }
        let server = viewModel.server(for: indexPath)
        delegate?.didSelectServer(server: server, in: self)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if let viewModel = viewModel, viewModel.servers.count == EnabledServersCoordinator.serversOrdered.count {
            return nil
        }

        let footer = UIView()
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = viewModel?.descriptionColor
        label.text = viewModel?.descriptionText
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: footer, edgeInsets: .init(top: 7, left: 20, bottom: 0, right: 20))
        ])
        return footer
    }
}
