// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AlphaWalletSettingsViewControllerDelegate: class {
    func didPressShowWallet(in viewController: AlphaWalletSettingsViewController)
}


class AlphaWalletSettingsViewController: UIViewController {
	enum Options {
		case myWalletAddress
        case notificationSettings
    }

    weak var delegate: AlphaWalletSettingsViewControllerDelegate?
    let tableView = UITableView()
    let rows: [(title: String, option: Options)] = [
        (title: R.string.localizable.aSettingsContentsMyWalletAddress(), option: .myWalletAddress),
        (title: R.string.localizable.aSettingsContentsNotificationsSettings(), option: .notificationSettings),
    ]

    init() {
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aSettingsNavigationTitle()

        view.backgroundColor = Colors.appBackground

        tableView.register(AlphaWalletSettingsViewCell.self, forCellReuseIdentifier: AlphaWalletSettingsViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AlphaWalletSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row].option {
        case .myWalletAddress:
            showWalletAddress()
        case .notificationSettings:
            showNotificationsSettings()
        }
    }

    private func showNotificationsSettings() {
        if let url = URL(string:UIApplicationOpenSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func showWalletAddress() {
		delegate?.didPressShowWallet(in: self)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

extension AlphaWalletSettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AlphaWalletSettingsViewCell.identifier, for: indexPath) as! AlphaWalletSettingsViewCell
		switch rows[indexPath.row].option {
        case .myWalletAddress:
            cell.configure(text: rows[indexPath.row].title, image: R.image.settings_wallet1())
        case .notificationSettings:
            cell.configure(text: rows[indexPath.row].title, image: R.image.settings_notifications())
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
}
