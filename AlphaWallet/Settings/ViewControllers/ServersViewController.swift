// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ServersViewControllerDelegate: AnyObject {
    func didClose(in viewController: ServersViewController)
    func didSelectServer(selection: ServerSelection, in viewController: ServersViewController)
}

class ServersViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = Configuration.Color.Semantic.tableViewSeparator
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(RPCDisplaySelectableTableViewCell.self)

        return tableView
    }()
    private var viewModel: ServersViewModel
    private let roundedBackground = RoundedBackground()
    weak var delegate: ServersViewControllerDelegate?

    init(viewModel: ServersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        
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

    private func configure(viewModel: ServersViewModel) {
        self.viewModel = viewModel
        navigationItem.title = viewModel.title
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ServersViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        if viewModel.multipleSessionSelectionEnabled && viewModel.serversHaveChanged {
            delegate?.didSelectServer(selection: .multipleServers(servers: viewModel.selectedServers), in: self)
        } else {
            delegate?.didClose(in: self)
        }
    }
}

extension ServersViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.servers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.viewModel(for: indexPath))

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let server = viewModel.server(for: indexPath)

        if viewModel.multipleSessionSelectionEnabled {
            if viewModel.isServerSelected(server) {
                viewModel.unselectServer(server: server)
            } else {
                viewModel.selectServer(server: server)
            }

            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            viewModel.selectServer(server: server)

            delegate?.didSelectServer(selection: .server(server: server), in: self)
        }
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
        guard viewModel.displayWarningFooter else { return nil }

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
