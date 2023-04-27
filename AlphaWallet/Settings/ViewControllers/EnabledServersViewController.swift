// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import Combine

protocol EnabledServersViewControllerDelegate: AnyObject {
    func didEditSelectedServer(customRpc: CustomRPC, in viewController: EnabledServersViewController)
    func didClose(in viewController: EnabledServersViewController)
}

class EnabledServersViewController: UIViewController {
    private let headers = (mainnet: EnableServersHeaderView(), testnet: EnableServersHeaderView())
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildPlainTableView()
        tableView.delegate = self
        tableView.register(RPCDisplaySelectableTableViewCell.self)
        tableView.isEditing = false

        return tableView
    }()
    private let viewModel: EnabledServersViewModel
    private let selection = PassthroughSubject<RPCServer, Never>()
    private let enableTestnet = PassthroughSubject<Bool, Never>()
    private let reload = PassthroughSubject<Void, Never>()
    private let deleteCustomRpc = PassthroughSubject<CustomRPC, Never>()
    private var cancellable = Set<AnyCancellable>()
    private lazy var dataSource = makeDataSource()

    weak var delegate: EnabledServersViewControllerDelegate?

    init(viewModel: EnabledServersViewModel) {
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
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EnabledServersViewModel) {

        let input = EnabledServersViewModelInput(
            selection: selection.eraseToAnyPublisher(),
            enableTestnet: enableTestnet.eraseToAnyPublisher(),
            deleteCustomRpc: deleteCustomRpc.eraseToAnyPublisher(),
            reload: reload.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self] viewState in
                self?.navigationItem.title = viewState.title
                self?.dataSource.apply(viewState.snapshot, animatingDifferences: false)
                self?.forceReloadSectionHeaders()
            }.store(in: &cancellable)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func confirmDelete(customRpc: CustomRPC) {
        Task { @MainActor in
            guard case .success = await confirm(
                title: R.string.localizable.settingsEnabledNetworksDeleteTitle(),
                message: R.string.localizable.settingsEnabledNetworksDeleteMessage(),
                okTitle: R.string.localizable.delete(),
                okStyle: .destructive) else { return }

                deleteCustomRpc.send(customRpc)
        }
    }

    private func edit(customRpc: CustomRPC) {
        delegate?.didEditSelectedServer(customRpc: customRpc, in: self)
    }

    //NOTE: for some reasons section view reloads not always, need to reload them manually
    private func forceReloadSectionHeaders() {
        for viewModel in dataSource.snapshot().sectionIdentifiers {
            switch viewModel.section {
            case .testnet:
                headers.testnet.configure(mode: .testnet, isEnabled: viewModel.isEnabled)
            case .mainnet:
                headers.mainnet.configure(mode: .mainnet, isEnabled: viewModel.isEnabled, isToggleHidden: true)
            }
        }
    }
}

extension EnabledServersViewController {
    private func makeDataSource() -> EnabledServersViewModel.DataSource {
        EnabledServersViewModel.DataSource(tableView: tableView) { tableView, indexPath, viewModel -> RPCDisplaySelectableTableViewCell? in
            let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}

extension EnabledServersViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        let headerView: EnableServersHeaderView
        let viewModel = dataSource.snapshot().sectionIdentifiers[section]
        switch viewModel.section {
        case .testnet:
            headerView = headers.testnet
            headerView.configure(mode: .testnet, isEnabled: viewModel.isEnabled)
        case .mainnet:
            headerView = headers.mainnet
            headerView.configure(mode: .mainnet, isEnabled: viewModel.isEnabled, isToggleHidden: true)
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard case .server(let server) = dataSource.item(at: indexPath).server else { return }
        selection.send(server)
        //Even if no servers is selected, we don't attempt to disable the back button here since calling code will take care of ignore the change server "request" when there are no servers selected. We don't want to disable the back button because users can't cancel the operation
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .server(let server) = dataSource.item(at: indexPath).server else { return nil }
        guard let customRpc = server.customRpc else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { _, _, complete in
            self.confirmDelete(customRpc: customRpc)
            complete(true)
        }

        deleteAction.image = R.image.close()?.withRenderingMode(.alwaysTemplate)
        deleteAction.backgroundColor = Configuration.Color.Semantic.dangerBackground

        let editAction = UIContextualAction(style: .normal, title: R.string.localizable.editButtonTitle()) { _, _, complete in
            self.edit(customRpc: customRpc)
            complete(true)
        }

         let configuration = UISwipeActionsConfiguration(actions: [editAction, deleteAction])

        return configuration
    }

}

extension EnabledServersViewController: EnableServersHeaderViewDelegate {
    func toggledTo(_ newValue: Bool, headerView: EnableServersHeaderView) {
        if newValue {
            let prompt = PromptViewController()
            prompt.configure(viewModel: .init(title: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetTitle(), description: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetDescription(), buttonTitle: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetButtonTitle()))

            prompt._delegate = self
            present(prompt, animated: true)
        } else {
            enableTestnet.send(false)
        }
    }
}

extension EnabledServersViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        reload.send(())
        delegate?.didClose(in: self)
    }
}

extension EnabledServersViewController: PromptViewControllerDelegate {
    func actionButtonTapped(inController controller: PromptViewController) {
        enableTestnet.send(true)
    }

    func didClose(in controller: PromptViewController) {
        enableTestnet.send(false)
    }
}
