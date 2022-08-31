//
//  InitialNetworkSelectionViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/5/22.
//

import UIKit
import AlphaWalletFoundation

protocol InitialNetworkSelectionViewModelDelegate: AnyObject {
    func reloadTable()
    func changeSelectionCount(rowCount: Int)
    func promptUserForTestnet(viewModel: InitialNetworkSelectionViewModel)
}

class InitialNetworkSelectionViewModel: NSObject {

    private let numberOfSections = InitialNetworkSelectionCollectionModel.Mode.allCases.count
    private var model: InitialNetworkSelectionCollectionModel
    private let headerForMainnet: EnableServersHeaderView = EnableServersHeaderView()
    private let headerForTestnet: EnableServersHeaderView = EnableServersHeaderView()
    private var rowCountCallback: InitialNetworkSelectionViewResultsCallback

    var selected: [RPCServer] {
        Array(model.selected)
    }

    weak var delegate: InitialNetworkSelectionViewModelDelegate?

    init(model: InitialNetworkSelectionCollectionModel, rowCountCallback: @escaping InitialNetworkSelectionViewResultsCallback = { _ in }) {
        self.model = model
        self.rowCountCallback = rowCountCallback
        super.init()
        configure()
    }

    private func configure() {
        headerForMainnet.configure(mode: .mainnet, isEnabled: model.mode == .mainnet)
        headerForTestnet.configure(mode: .testnet, isEnabled: model.mode == .testnet)
        headerForMainnet.delegate = self
        headerForTestnet.delegate = self
    }

    func set(rowCountCallback: @escaping InitialNetworkSelectionViewResultsCallback) {
        self.rowCountCallback = rowCountCallback
    }
}

extension InitialNetworkSelectionViewModel: UITableViewDataSource {

    func register(_ tableView: UITableView) {
        tableView.register(RPCDisplaySelectableTableViewCell.self)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let mode = getModeFromSectionIndex(index: section), mode == model.mode else {
            return 0 }
        let rowCount = model.countFor(mode: mode)
        self.rowCountCallback(rowCount)
        return rowCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let server = model.server(for: indexPath)
        let cellViewModel = ServerImageViewModel(server: .server(server), selected: model.isSelected(server: server))
        cell.configure(viewModel: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        50.0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let mode = getModeFromSectionIndex(index: section) else { return nil }
        switch mode {
        case .mainnet:
            return headerForMainnet
        case .testnet:
            return headerForTestnet
        }
    }

    private func getModeFromSectionIndex(index: Int) -> InitialNetworkSelectionCollectionModel.Mode? {
        guard let mode = InitialNetworkSelectionCollectionModel.Mode(rawValue: index) else { return nil }
        return mode
    }

}

extension InitialNetworkSelectionViewModel: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let server = model.server(for: indexPath)
        model.isSelected(server: server) ? model.removeSelected(server: server) : model.addSelected(server: server)
        tableView.reloadRows(at: [indexPath], with: .none)
        sendDelegateChangeSelectedCount()
    }

    private func sendDelegateChangeSelectedCount() {
        delegate?.changeSelectionCount(rowCount: model.selected.count)
    }

}

extension InitialNetworkSelectionViewModel: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        model.filter(keyword: searchText)
        sendDelegateReloadTable()
    }

    private func sendDelegateReloadTable() {
        delegate?.reloadTable()
    }

}

extension InitialNetworkSelectionViewModel: EnableServersHeaderViewDelegate {

    func toggledTo(_ newValue: Bool, headerView: EnableServersHeaderView) {
        switch (newValue, headerView.mode) {
        case (true, .mainnet), (false, .testnet):
            model.set(mode: .mainnet)
            headerForMainnet.toggle(isEnabled: true)
            headerForTestnet.toggle(isEnabled: false)
            sendDelegateReloadTable()
            sendDelegateChangeSelectedCount()
        case (false, .mainnet), (true, .testnet):
            sendDelegatePromptUserForTestnet()
        }
    }

    private func sendDelegatePromptUserForTestnet() {
        delegate?.promptUserForTestnet(viewModel: self)
    }

}

extension InitialNetworkSelectionViewModel: PromptViewControllerDelegate {

    func actionButtonTapped(inController controller: PromptViewController) {
        model.set(mode: .testnet)
        headerForMainnet.toggle(isEnabled: false)
        headerForTestnet.toggle(isEnabled: true)
        sendDelegateReloadTable()
        sendDelegateChangeSelectedCount()
    }

    func controllerDismiss(_ controller: PromptViewController) {
        headerForMainnet.toggle(isEnabled: true)
        headerForTestnet.toggle(isEnabled: false)
        sendDelegateReloadTable()
    }

}
