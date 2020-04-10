//
//  SettingsViewController2.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 06/04/20.
//

import UIKit

class SettingsViewController2: UIViewController {
    private let settingsWalletData = SettingConnector.getWalletSettings()
    private let settingsSystemData = SettingConnector.getSystemSettings()
    private let settingsHelpData = SettingConnector.getHelpSettings()
    private let settingsFooterData = SettingConnector.getSettingsFooter()
    
    let settingTableView = UITableView() // view
    private let keystore: Keystore
    private let account: Wallet
   
    init(keystore: Keystore, account: Wallet) {
        self.keystore = keystore
        self.account = account
        
        super.init(nibName: nil, bundle: nil)
        self.title = R.string.localizable.aSettingsNavigationTitle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Screen.Setting.Color.background
        view.addSubview(settingTableView)

        settingTableView.translatesAutoresizingMaskIntoConstraints = false
        settingTableView.showsVerticalScrollIndicator = false
        settingTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        settingTableView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        settingTableView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        settingTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        settingTableView.dataSource = self
        settingTableView.delegate = self
        
        settingTableView.register(SettingViewHeader.self, forHeaderFooterViewReuseIdentifier: "SettingHeaderView")
        settingTableView.register(SettingTableViewCell.self, forCellReuseIdentifier: "settingCell")
        settingTableView.register(AppInfoTableCell.self, forCellReuseIdentifier: "appInfoCell")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension SettingsViewController2: UITableViewDataSource, UITableViewDelegate {
        public func numberOfSections(in tableView: UITableView) -> Int {
            return 4
        }
    
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch section {
            case 0:
                return settingsWalletData.count
            case 1:
                return settingsSystemData.count
            case 2:
                return settingsHelpData.count
            default:
                return settingsFooterData.count
            }
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            if indexPath.section == 3 {
                let cells = tableView.dequeueReusableCell(withIdentifier: "appInfoCell", for: indexPath) as? AppInfoTableCell
                              cells!.selectionStyle = .none
                              cells!.settings = settingsFooterData[indexPath.row]
                return cells!
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "settingCell", for: indexPath) as! SettingTableViewCell
                cell.selectionStyle = .none
                cell.accessoryType = .disclosureIndicator
                cell.delegate = self
                if indexPath.row == 1 && indexPath.section == 1 {
                    cell.tableSwitch.isHidden = false
                    cell.accessoryType = .none
                }
                switch indexPath.section {
                case 0:
                    cell.settings = settingsWalletData[indexPath.row]
                case 1:
                    cell.settings = settingsSystemData[indexPath.row]
                case 2:
                    cell.settings = settingsHelpData[indexPath.row]
                default:
                   cell.settings = settingsHelpData[indexPath.row]
                }
                return cell
            }
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            if indexPath.row == 1 && indexPath.section == 0 {
                return 80
            } else if indexPath.section == 3 {
                return  50
            }
            return 60
        }
    
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            if section == 3 {
                return 0
            }
            return 50
        }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SettingHeaderView") as! SettingViewHeader
        if section == 0 {
            headerView.title = "WALLET"
        } else if section == 1 {
            headerView.title = "SYSTEM"
        } else {
            headerView.title = "HELP"
        }
        return headerView
    }
}
extension SettingsViewController2: SettingTableViewCellDelegate {
    func onOffPassCode(cell: SettingTableViewCell, switchState isOnOff: Bool) {
        if isOnOff {
            print("Switch is On")
        } else {
            print("Switch is Off")
        }
    }
}
