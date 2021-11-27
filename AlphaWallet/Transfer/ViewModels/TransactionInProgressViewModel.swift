//
//  TransactionInProgressViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.07.2020.
//

import UIKit

struct TransactionInProgressViewModel {
    
    private let account: Wallet
    
    init(account: Wallet) {
        self.account = account
    }
    var titleAttributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return NSAttributedString(string: R.string.localizable.aWalletTokenTransactionInProgressTitle(), attributes: [
            .paragraphStyle: style,
            .font: Fonts.bold(size: 18),
            .foregroundColor: Colors.headerThemeColor
        ])
    }

    var subtitleAttributedText: NSAttributedString {
        let x = R.string.localizable.aWalletTokenTransactionInProgressSubtitle()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 7 : 14
        return NSMutableAttributedString(string: x, attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: 10),
            .foregroundColor: Colors.headerThemeColor
        ])
    }

    var okButtonTitle: String {
        return R.string.localizable.aWalletTokenTransactionInProgressConfirm()
    }

    var okButtonTitleColor: UIColor {
        Colors.headerThemeColor
    }
    
    var image: UIImage? {
        return R.image.conversionDaiSai()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
    
    var addressFont: UIFont {
        return Fonts.semibold(size: 10)
    }
    
    var addressBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var myAddressText: String {
        return account.address.eip55String
    }

    var myAddress: AlphaWallet.Address {
        return account.address
    }

    var copyWalletText: String {
        return R.string.localizable.requestCopyWalletButtonTitle()
    }

    var addressCopiedText: String {
        return R.string.localizable.requestAddressCopiedTitle()
    }
    
    var addressLabelColor: UIColor {
        return Colors.headerThemeColor
    }

    var copyButtonsFont: UIFont {
        return Fonts.semibold(size: 17)
    }
    
}

