//
//  CurrencyTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.06.2020.
//

import UIKit
import AlphaWalletFoundation

struct CurrencyTableViewCellViewModel: Hashable {
    let code: String
    let name: String?
    let icon: UIImage?
    let isSelected: Bool

    init(currency: Currency, isSelected: Bool) {
        code = currency.code
        name = currency.name
        icon = currency.icon
        self.isSelected = isSelected
    }

    var accessoryType: UITableViewCell.AccessoryType {
        if isSelected {
            return LocaleViewCell.selectionAccessoryType.selected
        } else {
            return LocaleViewCell.selectionAccessoryType.unselected
        }
    }
}
