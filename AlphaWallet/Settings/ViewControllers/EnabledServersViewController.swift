// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol EnabledServersViewControllerDelegate: AnyObject {
    func didEditSelectedServer(customRpc: CustomRPC, in viewController: EnabledServersViewController)
    func notifyReloadServersQueued(in viewController: EnabledServersViewController)
}

class EnabledServersViewController: UIViewController {
    enum Section {
        case testnet
        case mainnet
    }

    private let roundedBackground = RoundedBackground()
    private let headers = (mainnet: EnableServersHeaderView(), testnet: EnableServersHeaderView())
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(RPCDisplaySelectableTableViewCell.self)
        tableView.dataSource = self
        tableView.isEditing = false

        return tableView
    }()
    private let restartQueue: RestartTaskQueue
    private let sections: [Section] = [.mainnet, .testnet]
    private var serversSelectedInPreviousMode: [RPCServer]?
    private var sectionIndices: IndexSet {
        IndexSet(integersIn: Range(uncheckedBounds: (lower: 0, sections.count)))
    }
    private let config: Config = Config()

    var viewModel: EnabledServersViewModel
    weak var delegate: EnabledServersViewControllerDelegate?

    init(viewModel: EnabledServersViewModel, restartQueue: RestartTaskQueue) {
        self.viewModel = viewModel
        self.restartQueue = restartQueue
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

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
        guard pushReloadServersIfNeeded() else { return }
        delegate?.notifyReloadServersQueued(in: self)
    }

    @discardableResult func pushReloadServersIfNeeded() -> Bool {
        let servers = viewModel.selectedServers
        //Defensive. Shouldn't allow no server to be selected
        guard !servers.isEmpty else { return false }

        let isUnchanged = Set(config.enabledServers) == Set(servers)
        if isUnchanged {
            //no-op
        } else {
            restartQueue.add(.reloadServers(servers))
        }
        return !isUnchanged
    }

    private func confirmDelete(server: RPCServer) {
        confirm(title: R.string.localizable.settingsEnabledNetworksDeleteTitle(), message: R.string.localizable.settingsEnabledNetworksDeleteMessage(), okTitle: R.string.localizable.delete(), okStyle: .destructive) { [weak self] result in
            switch result {
            case .success:
                self?.markForDeletion(server: server)
            case .failure:
                break
            }
        }
    }

    private func edit(server: RPCServer) {
        guard let customRpc = server.customRpc else { return }
        delegate?.didEditSelectedServer(customRpc: customRpc, in: self)
    }

    private func markForDeletion(server: RPCServer) {
        guard let customRpc = server.customRpc else { return }
        pushReloadServersIfNeeded()
        restartQueue.add(.removeServer(customRpc))

        delegate?.notifyReloadServersQueued(in: self)
    }
}

extension EnabledServersViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .testnet:
            return viewModel.serverCount(forMode: .testnet)
        case .mainnet:
            return viewModel.serverCount(forMode: .mainnet)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: EnableServersHeaderView
        switch sections[section] {
        case .testnet:
            headerView = headers.testnet
            headerView.configure(mode: .testnet, isEnabled: viewModel.mode == .testnet)
        case .mainnet:
            headerView = headers.mainnet
            headerView.configure(mode: .mainnet, isEnabled: viewModel.mode == .mainnet)
        }
        headerView.delegate = self
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let server = viewModel.server(for: indexPath)
        let cellViewModel = ServerImageViewModel(server: .server(server), selected: viewModel.isServerSelected(server))
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
        configure(viewModel: .init(servers: viewModel.servers, selectedServers: servers, mode: viewModel.mode))
        tableView.reloadData()
        //Even if no servers is selected, we don't attempt to disable the back button here since calling code will take care of ignore the change server "request" when there are no servers selected. We don't want to disable the back button because users can't cancel the operation
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let server = viewModel.server(for: indexPath)
        guard server.isCustom else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { _, _, complete in
            self.confirmDelete(server: server)
            complete(true)
        }

        deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
        deleteAction.backgroundColor = R.color.danger()

        let editAction = UIContextualAction(style: .normal, title: R.string.localizable.editButtonTitle()) { _, _, complete
            in
            self.edit(server: server)
            complete(true)
        }

         let configuration = UISwipeActionsConfiguration(actions: [editAction, deleteAction])

        return configuration
    }

}

extension EnabledServersViewController: EnableServersHeaderViewDelegate {
    func toggledTo(_ newValue: Bool, headerView: EnableServersHeaderView) {
        switch (headerView.mode, newValue) {
        case (.mainnet, true), (.testnet, false):
            if let serversSelectedInPreviousMode = serversSelectedInPreviousMode {
                self.serversSelectedInPreviousMode = viewModel.selectedServers
                configure(viewModel: .init(servers: viewModel.servers, selectedServers: serversSelectedInPreviousMode, mode: .mainnet))
            } else {
                serversSelectedInPreviousMode = viewModel.selectedServers
                configure(viewModel: .init(servers: viewModel.servers, selectedServers: Constants.defaultEnabledServers, mode: .mainnet))
            }
            tableView.reloadData()
            tableView.reloadSections(sectionIndices, with: .automatic)
        case (.mainnet, false), (.testnet, true):
            let prompt = PromptViewController()
            prompt.configure(viewModel: .init(title: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetTitle(), description: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetDescription(), buttonTitle: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetButtonTitle()))

            prompt._delegate = self
            present(prompt, animated: true)
        }
    }
}

extension EnabledServersViewController: PromptViewControllerDelegate {
    func actionButtonTapped(inController controller: PromptViewController) {
        if let serversSelectedInPreviousMode = serversSelectedInPreviousMode {
            self.serversSelectedInPreviousMode = viewModel.selectedServers
            configure(viewModel: .init(servers: viewModel.servers, selectedServers: serversSelectedInPreviousMode, mode: .testnet))
        } else {
            serversSelectedInPreviousMode = viewModel.selectedServers
            configure(viewModel: .init(servers: viewModel.servers, selectedServers: Constants.defaultEnabledTestnetServers, mode: .testnet))
        }
        //Animation breaks section headers. No idea why. So don't animate
        tableView.reloadData()
    }

    func controllerDismiss(_ controller: PromptViewController) {
        headers.mainnet.configure(mode: .mainnet, isEnabled: true)
        headers.testnet.configure(mode: .testnet, isEnabled: false)
    }
}
