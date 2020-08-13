//
//  TransactionInProgressViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.07.2020.
//

import UIKit

struct TransactionInProgressViewModel {

    var titleAttributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return NSAttributedString(string: R.string.localizable.aWalletTokenTransactionInProgressTitle(), attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: 28)!,
            .foregroundColor: Colors.black
        ])
    }

    var subtitleAttributedText: NSAttributedString {
        let x = R.string.localizable.aWalletTokenTransactionInProgressSubtitle()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 7 : 14

        return NSMutableAttributedString(string: x, attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: 17)!,
            .foregroundColor: R.color.mine()!
        ])
    }

    var okButtonTitle: String {
        return R.string.localizable.aWalletTokenTransactionInProgressConfirm()
    }

    var image: UIImage? {
        return R.image.conversionDaiSai()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}

