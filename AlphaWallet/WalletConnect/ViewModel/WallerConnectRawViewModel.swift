//
//  WallerConnectRawViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.07.2020.
//

import UIKit

struct WallerConnectRawViewModel {

    var text: String
    var details: String
    var detailsLabelFont: UIFont = Fonts.regular(size: 17)
    var detailsLabelTextColor: UIColor = R.color.black()!
    var hideSeparatorOptions: HideSeparatorOption = .none

    var separatorLineColor: UIColor {
        return R.color.mercury()!
    }

    var textLabelTextColor: UIColor {
        return R.color.dove()!
    }

    var textLabelFont: UIFont {
        return Fonts.regular(size: 13)
    }
}

enum HideSeparatorOption {
    case top
    case bottom
    case none
    case both
}
