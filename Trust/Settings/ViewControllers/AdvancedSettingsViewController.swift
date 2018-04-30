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
        tableView.backgroundColor = Colors.appBackground

        navigationItem.title = viewModel.title

        form +++ Section()

                <<< AlphaWalletSettingPushRow<RPCServer> { [weak self] in
            guard let strongSelf = self else {
                return
            }
            $0.title = strongSelf.viewModel.networkTitle
            $0.options = strongSelf.viewModel.servers
            $0.value = RPCServer(chainID: strongSelf.config.chainID)
            $0.selectorTitle = strongSelf.viewModel.networkTitle
            $0.displayValueFor = { value in
                return value?.displayName
            }
        }.onChange {[weak self] row in
            self?.config.chainID = row.value?.chainID ?? RPCServer.main.chainID
            self?.run(action: .RPCServer)
        }.onPresent { _, selectorController in
            selectorController.enableDeselection = false
            selectorController.sectionKeyForValue = { option in
                switch option {
                case .main, .classic, .callisto, .poa: return ""
                case .kovan, .ropsten, .rinkeby, .sokol: return R.string.localizable.settingsNetworkTestLabelTitle()
                case .custom:
                    return NSLocalizedString("settings.network.custom.label.title", value: "Custom", comment: "")
                }
            }
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
            cell.imageView?.image = R.image.settings_server()?.withRenderingMode(.alwaysTemplate)
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

