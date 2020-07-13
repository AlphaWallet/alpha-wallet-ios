//
//  ConfirmTransactionTableViewHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit

struct ConfirmTransactionTableViewHeaderViewModel {
    let title: String
    let placeholder: String
    var details: String = String()
    let isOpened: Bool
    let section: Int
    var shouldHideExpandButton: Bool = false

    var titleLabelFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var titleLabelColor: UIColor {
        return R.color.black()!
    }

    var placeholderLabelFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var placeholderLabelColor: UIColor {
        return R.color.dove()!
    }

    var detailsLabelFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var detailsLabelColor: UIColor {
        return R.color.dove()!
    }

    var backgoundColor: UIColor {
        return Colors.appBackground
    }
}
