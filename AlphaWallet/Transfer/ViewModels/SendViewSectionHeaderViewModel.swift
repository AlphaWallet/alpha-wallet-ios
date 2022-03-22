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
    var textColor: UIColor = R.color.dove()!
    var backgroundColor: UIColor = R.color.alabaster()!
    var separatorBackgroundColor: UIColor = R.color.mike()!
}

