// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Eureka

protocol AdvancedSettingsViewControllerDelegate: class {
    func didAction(action: AlphaWalletSettingsAction, in viewController: AdvancedSettingsViewController)
}

class AdvancedSettingsViewController: FormViewController {

    private var account: Wallet
    private var config: Config
    weak var delegate: AdvancedSettingsViewControllerDelegate?
    let viewModel = AdvancedSettingsViewModel()

    init(
		account: Wallet,
		config: Config
    ) {
        self.account = account
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.appBackground
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground

        navigationItem.title = viewModel.title

        form +++ Section()

                <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .servers)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else {
                return
            }
            cell.imageView?.image = R.image.settings_server()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = R.string.localizable.settingsNetworkButtonTitle()
            cell.detailTextLabel?.text = RPCServer(chainID: strongSelf.config.chainID).displayName
            cell.accessoryType = .disclosureIndicator
        }

                <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .wallets)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { cell, _ in
            cell.imageView?.image = R.image.settings_wallet()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = R.string.localizable.settingsWalletsButtonTitle()
            cell.detailTextLabel?.text = String(self.account.address.description.prefix(10)) + "..."
            cell.accessoryType = .disclosureIndicator
        }

                <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .locales)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else {
                return
            }
            cell.imageView?.image = R.image.settings_language()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = strongSelf.viewModel.localeTitle
            cell.detailTextLabel?.text = AppLocale(id: strongSelf.config.locale).displayName
            cell.accessoryType = .disclosureIndicator
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func run(action: AlphaWalletSettingsAction) {
        delegate?.didAction(action: action, in: self)
    }

    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = Colors.appBackground
        return v
    }

    override open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = Colors.appBackground
        return v
    }
}

