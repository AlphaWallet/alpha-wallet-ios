//
//  WallerConnectRowViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.07.2020.
//

import UIKit

struct WallerConnectRowViewModel {
    var text: String
    var details: String
    var detailsLabelFont: UIFont = Fonts.regular(size: 17)
    var detailsLabelTextColor: UIColor = R.color.black()!
    var hideSeparatorOptions: HideSeparatorOption = .none
    var separatorLineColor: UIColor = R.color.mercury()!
    var textLabelTextColor: UIColor = R.color.dove()!
    var textLabelFont: UIFont = Fonts.regular(size: 13)
}

enum HideSeparatorOption {
    case top
    case bottom
    case none
    case both
}
