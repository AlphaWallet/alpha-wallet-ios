//
//  InitialNetworkSelectionViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/5/22.
//

import UIKit

class InitialNetworkSelectionViewModel: NSObject {

    static let ReloadTableViewNotification: Notification.Name = Notification.Name("InitialNetworkSelectionViewModel.Reload")
    private var model: InitialNetworkSelectionCollectionModel
    private var tableView: UITableView?

    init(model: InitialNetworkSelectionCollectionModel) {
        self.model = model
        super.init()
    }

}

extension InitialNetworkSelectionViewModel: UITableViewDataSource {

    func register(_ tableView: UITableView) {
        tableView.register(ServerImageTableViewCell.self)
        self.tableView = tableView
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ServerImageTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let server = model.server(for: indexPath)
        let cellViewModel = ServerImageViewModel(server: server, selected: model.isSelected(server: server))
        cell.configure(viewModel: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80.0
    }

}

extension InitialNetworkSelectionViewModel: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let server = model.server(for: indexPath)
        model.isSelected(server: server) ? model.removeSelected(server: server) : model.addSelected(server: server)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}

extension InitialNetworkSelectionViewModel: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        model.filter(keyword: searchText)
        sendReloadNotification()
    }

    private func sendReloadNotification() {
        NotificationCenter.default.post(name: InitialNetworkSelectionViewModel.ReloadTableViewNotification, object: self)
    }
}
