//
//  SendViewSectionHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

struct SendViewSectionHeaderViewModel {
    let text: String
    var showTopSeparatorLine: Bool = true
    var showBottomSeparatorLine: Bool = true
    var font: UIFont = Fonts.semibold(size: 15)
    var textColor: UIColor = Configuration.Color.Semantic.defaultSubtitleText
    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewHeaderBackground
    var separatorBackgroundColor: UIColor = Configuration.Color.Semantic.tableViewSeparator
}

