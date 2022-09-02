//
//  FeaturesTableViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/1/22.
//

import UIKit
import AlphaWalletFoundation

fileprivate class DisplayTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FeaturesTableViewController: UITableViewController {

    private static let cellIdentifier: String = String(describing: FeaturesTableViewController.self)

    private var features: Features
    private var keys: [FeaturesAvailable] = FeaturesAvailable.allCases

    init(features: Features) {
        self.features = features
        self.keys = self.keys.sorted { beforeKey, afterKey in
            beforeKey.rawValue < afterKey.rawValue
        }
        super.init(nibName: nil, bundle: nil)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RPCDisplayTableViewCell.self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keys.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: RPCDisplayTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        return configure(cell: cell, at: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = keys[indexPath.row]
        features.invert(key)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    private func configure(cell: UITableViewCell, at indexPath: IndexPath) -> UITableViewCell {
        let key = keys[indexPath.row]
        let value = features.isAvailable(key)
        cell.textLabel?.font = Fonts.regular(size: 12)
        cell.textLabel?.text = key.rawValue.insertSpaceBeforeCapitals()
        cell.accessoryType = value ? .checkmark : .none
        return cell
    }

}
