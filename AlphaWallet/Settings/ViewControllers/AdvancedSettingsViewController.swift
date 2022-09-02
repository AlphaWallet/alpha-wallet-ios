//
//  AdvancedSettingsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit
import AlphaWalletFoundation

protocol AdvancedSettingsViewControllerDelegate: AnyObject {
    func advancedSettingsViewControllerMoreSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerClearBrowserCacheSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerTokenScriptSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerChangeLanguageSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerChangeCurrencySelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerAnalyticsSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerUsePrivateNetworkSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerExportJSONKeystoreSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerFeaturesSelected(in controller: AdvancedSettingsViewController)
}

class AdvancedSettingsViewController: UIViewController {

    private lazy var viewModel: AdvancedSettingsViewModel = AdvancedSettingsViewModel(wallet: wallet)
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private let roundedBackground = RoundedBackground()
    private var config: Config
    private let wallet: Wallet
    weak var delegate: AdvancedSettingsViewControllerDelegate?

    init(wallet: Wallet, config: Config) {
        self.config = config
        self.wallet = wallet
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

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

        title = R.string.localizable.aAdvancedSettingsNavigationTitle()
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure() {
        tableView.reloadData()
    }
}

extension AdvancedSettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rows[indexPath.row]
        switch row {
        case .analytics, .changeCurrency, .changeLanguage, .clearBrowserCache, .tools, .tokenScript, .exportJSONKeystore, .features:
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(titleText: row.title, subTitleText: nil, icon: row.icon))
            return cell
        case .usePrivateNetwork:
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let provider = config.sendPrivateTransactionsProvider
            let subtitle: String? = provider?.title
            let icon: UIImage? = provider?.icon ?? row.icon
            cell.configure(viewModel: .init(titleText: row.title, subTitleText: subtitle, icon: icon))
            return cell
        }
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
            delegate?.advancedSettingsViewControllerMoreSelected(in: self)
        case .clearBrowserCache:
            delegate?.advancedSettingsViewControllerClearBrowserCacheSelected(in: self)
        case .tokenScript:
            delegate?.advancedSettingsViewControllerTokenScriptSelected(in: self)
        case .changeLanguage:
            delegate?.advancedSettingsViewControllerChangeLanguageSelected(in: self)
        case .changeCurrency:
            delegate?.advancedSettingsViewControllerChangeCurrencySelected(in: self)
        case .analytics:
            delegate?.advancedSettingsViewControllerAnalyticsSelected(in: self)
        case .usePrivateNetwork:
            delegate?.advancedSettingsViewControllerUsePrivateNetworkSelected(in: self)
        case .exportJSONKeystore:
            delegate?.advancedSettingsViewControllerExportJSONKeystoreSelected(in: self)
        case .features:
            delegate?.advancedSettingsViewControllerFeaturesSelected(in: self)
        }
    }
}
