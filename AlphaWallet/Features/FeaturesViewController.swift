//
//  FeaturesViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/1/22.
//

import UIKit
import AlphaWalletFoundation

class FeaturesViewController: UIViewController {

    // MARK: - User Interface

    private let features: Features = Features.current

    private lazy var tableViewController: FeaturesTableViewController = {
        let controller = FeaturesTableViewController(features: features)
        controller.tableView.translatesAutoresizingMaskIntoConstraints = false
        return controller
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.setTitle("Reset", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewController()
    }

    // MARK: - Configurations

    private func configureViewController() {
        addTableViewController()
        addButton()
        navigationItem.title = R.string.localizable.advancedSettingsFeaturesTitle(preferredLanguages: nil)
    }

    private func addTableViewController() {
        addChild(tableViewController)
        view.addSubview(tableViewController.tableView)
        NSLayoutConstraint.activate([
            tableViewController.tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableViewController.tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableViewController.tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
        tableViewController.didMove(toParent: self)
    }

    private func addButton() {
        view.addSubview(resetButton)
        resetButton.addTarget(self, action: #selector(handleResetAction), for: .touchUpInside)

        NSLayoutConstraint.activate([
            resetButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            resetButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableViewController.tableView.bottomAnchor.constraint(equalTo: resetButton.topAnchor),
        ])
    }

    // MARK: - Objc functions

    @objc private func handleResetAction() {
        features.reset()
        tableViewController.tableView.reloadData()
    }

}
