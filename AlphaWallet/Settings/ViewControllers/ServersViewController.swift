// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ServersViewControllerDelegate: AnyObject {
    func didClose(in viewController: ServersViewController)
    func didSelectServer(selection: ServerSelection, in viewController: ServersViewController)
}

class ServersViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(RPCDisplaySelectableTableViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self

        return tableView
    }()
    private var viewModel: ServersViewModel

    weak var delegate: ServersViewControllerDelegate?

    init(viewModel: ServersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
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
        if viewModel.serversHaveChanged {
            if viewModel.multipleSessionSelectionEnabled && !viewModel.selectedServers.isEmpty {
                delegate?.didSelectServer(selection: .multipleServers(servers: viewModel.selectedServers), in: self)
            } else if let server = viewModel.selectedServers.first {
                delegate?.didSelectServer(selection: .server(server: server), in: self)
            }
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
        
        viewModel.selectOrDeselectServer(indexPath: indexPath)

        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
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
