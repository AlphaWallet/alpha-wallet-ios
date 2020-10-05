//
//  AdvancedSettingsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

protocol AdvancedSettingsViewControllerDelegate: class {
    func advancedSettingsViewControllerConsoleSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerClearBrowserCacheSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerTokenScriptSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerChangeLanguageSelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerChangeCurrencySelected(in controller: AdvancedSettingsViewController)
    func advancedSettingsViewControllerAnalyticsSelected(in controller: AdvancedSettingsViewController)
}

class AdvancedSettingsViewController: UIViewController {

    private lazy var viewModel: AdvancedSettingsViewModel = AdvancedSettingsViewModel()
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background

        return tableView
    }()
    weak var delegate: AdvancedSettingsViewControllerDelegate?

    override func loadView() {
        view = tableView
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string.localizable.aAdvancedSettingsNavigationTitle()
        view.backgroundColor = GroupedTable.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = GroupedTable.Color.background
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension AdvancedSettingsViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.cellViewModel(indexPath: indexPath))

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
        case .console:
            delegate?.advancedSettingsViewControllerConsoleSelected(in: self)
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
        }
    }
}
