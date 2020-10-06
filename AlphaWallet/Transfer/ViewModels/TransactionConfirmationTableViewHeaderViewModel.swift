//
//  TransactionConfirmationTableViewHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit

struct TransactionConfirmationTableViewHeaderViewModel {
    let title: String
    let placeholder: String
    let details: String = String()

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

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
