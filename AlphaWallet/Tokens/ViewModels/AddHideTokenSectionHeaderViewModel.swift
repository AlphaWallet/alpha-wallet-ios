//
//  AddHideTokenSectionHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2020.
//

import UIKit

struct AddHideTokenSectionHeaderViewModel {
    let titleText: String
    var separatorColor: UIColor = Configuration.Color.Semantic.tableViewSeparator
    var titleTextFont: UIFont = Fonts.bold(size: 24)
    var titleTextColor: UIColor = Configuration.Color.Semantic.defaultForegroundText

    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewHeaderBackground
    var showTopSeparator: Bool = false
}
