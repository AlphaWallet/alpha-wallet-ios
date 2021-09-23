//
//  ShowAddHideTokensViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import UIKit

struct ShowAddHideTokensViewModel {

    var addHideTokensIcon: UIImage? = nil

    var addHideTokensTitle: String? = R.string.localizable.walletsAddHideTokensTitle()

    var addHideTokensTintColor: UIColor {
        Colors.appTint
    }

    var addHideTokensTintFont: UIFont? {
        Screen.Tokens.addHideTokenFont
    }

    var badgeBackgroundColor: UIColor? {
        R.color.radical()
    }

    var backgroundColor: UIColor = Colors.appWhite

    var badgeText: String?
}
