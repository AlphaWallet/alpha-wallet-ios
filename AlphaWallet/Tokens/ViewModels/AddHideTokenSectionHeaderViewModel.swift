//
//  AddHideTokenSectionHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2020.
//

import UIKit

struct AddHideTokenSectionHeaderViewModel {
    let titleText: String
    var separatorColor: UIColor = GroupedTable.Color.cellSeparator
    var titleTextFont: UIFont = Fonts.bold(size: 24)
    var titleTextColor: UIColor = .black

    var backgroundColor: UIColor = Colors.appBackground
    var showTopSeparator: Bool = false
}
