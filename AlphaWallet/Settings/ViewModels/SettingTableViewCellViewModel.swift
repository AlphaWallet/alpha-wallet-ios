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
    let icon: UIImage

    var subTitleHidden: Bool {
        return subTitleText == nil
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var titleTextColor: UIColor {
        return Colors.black
    }

    var subTitleFont: UIFont {
        return Fonts.regular(size: 12)!
    }

    var subTitleTextColor: UIColor {
        return R.color.dove()!
    }
}

extension SettingTableViewCellViewModel {
    init(settingsSystemRow row: SettingsSystemRow) {
        titleText = row.title
        icon = row.icon
    }

    init(settingsWalletRow row: SettingsWalletRow) {
        titleText = row.title
        icon = row.icon
    }
}
