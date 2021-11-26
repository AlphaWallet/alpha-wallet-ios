//
//  AddHideTokenSectionHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2020.
//

import UIKit

struct AddHideTokenSectionHeaderViewModel {
    let titleText: String
    var separatorColor: UIColor = Colors.clear
    var titleTextFont: UIFont = Fonts.bold(size: 14)
    var titleTextColor: UIColor = Colors.headerThemeColor

    var backgroundColor: UIColor = Colors.appBackground
    var showTopSeparator: Bool = false
}
