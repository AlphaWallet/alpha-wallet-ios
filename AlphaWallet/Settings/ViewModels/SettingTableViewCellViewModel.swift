//
//  settingModel.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 06/04/20.
//

import UIKit

struct SettingTableViewCellViewModel {
    let titleText: String
    var subTitleText: String?
    let icon: UIImage?
    var accessoryType: UITableViewCell.AccessoryType = .none
    var accessoryView: UIView?

    var subTitleHidden: Bool {
        return subTitleText == nil
    }

    var titleFont: UIFont = Fonts.regular(size: 17)
    var titleTextColor: UIColor = Configuration.Color.Semantic.tableViewCellPrimaryFont
    var subTitleFont: UIFont = Fonts.regular(size: 12)
    var subTitleTextColor: UIColor = Configuration.Color.Semantic.tableViewCellSecondaryFont
}

extension SettingTableViewCellViewModel: Hashable {
    init(settingsSystemRow row: SettingsViewModel.SettingsSystemRow) {
        titleText = row.title
        icon = row.icon
    }

    init(settingsWalletRow row: SettingsViewModel.SettingsWalletRow) {
        titleText = row.title
        icon = row.icon
    }
    static func == (lhs: SettingTableViewCellViewModel, rhs: SettingTableViewCellViewModel) -> Bool {
        return lhs.titleText == rhs.titleText && lhs.icon == rhs.icon && lhs.subTitleText == rhs.subTitleText && lhs.accessoryType == rhs.accessoryType && lhs.accessoryView == rhs.accessoryView
    }
}
