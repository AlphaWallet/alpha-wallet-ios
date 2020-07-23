//
//  TransactionConfirmationTableViewHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit

struct TransactionConfirmationTableViewHeaderViewModel {
    
    enum HeaderViewExpandingState {
        case opened(section: Int, isOpened: Bool)
        case closed

        var shouldHideExpandButton: Bool {
            switch self {
            case .opened:
                return false
            case .closed:
                return true
            }
        }
    }

    let title: String
    let placeholder: String
    var details: String = String()
    var expandingState: HeaderViewExpandingState = .closed

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
