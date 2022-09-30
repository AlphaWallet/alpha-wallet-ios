//
//  AdvancedSettingsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit
import AlphaWalletFoundation

protocol AdvancedSettingsViewControllerDelegate: AnyObject {
    func moreSelected(in controller: AdvancedSettingsViewController)
    func clearBrowserCacheSelected(in controller: AdvancedSettingsViewController)
    func tokenScriptSelected(in controller: AdvancedSettingsViewController)
    func changeLanguageSelected(in controller: AdvancedSettingsViewController)
    func changeCurrencySelected(in controller: AdvancedSettingsViewController)
    func analyticsSelected(in controller: AdvancedSettingsViewController)
    func usePrivateNetworkSelected(in controller: AdvancedSettingsViewController)
    func exportJSONKeystoreSelected(in controller: AdvancedSettingsViewController)
    func featuresSelected(in controller: AdvancedSettingsViewController)
}

class AdvancedSettingsViewController: UIViewController {
    private let viewModel: AdvancedSettingsViewModel
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = Configuration.Color.Semantic.tableViewSeparator
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    weak var delegate: AdvancedSettingsViewControllerDelegate?

    init(viewModel: AdvancedSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: AdvancedSettingsViewModel) {
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = viewModel.largeTitleDisplayMode
    }
}

extension AdvancedSettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.viewModel(for: indexPath))

        return cell
    }
}

extension AdvancedSettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.rows[indexPath.row] {
        case .tools:
            delegate?.moreSelected(in: self)
        case .clearBrowserCache:
            delegate?.clearBrowserCacheSelected(in: self)
        case .tokenScript:
            delegate?.tokenScriptSelected(in: self)
        case .changeLanguage:
            delegate?.changeLanguageSelected(in: self)
        case .changeCurrency:
            delegate?.changeCurrencySelected(in: self)
        case .analytics:
            delegate?.analyticsSelected(in: self)
        case .usePrivateNetwork:
            delegate?.usePrivateNetworkSelected(in: self)
        case .exportJSONKeystore:
            delegate?.exportJSONKeystoreSelected(in: self)
        case .features:
            delegate?.featuresSelected(in: self)
        }
    }
}
