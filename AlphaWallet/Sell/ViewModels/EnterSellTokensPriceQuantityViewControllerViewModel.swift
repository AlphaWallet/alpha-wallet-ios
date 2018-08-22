// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct EnterSellTokensPriceQuantityViewControllerViewModel {

    var token: TokenObject
    var TokenHolder: TokenHolder
    var ethCost: String = "0"
    var dollarCost: String = ""

    var headerTitle: String {
		return R.string.localizable.aWalletTokenTokenSellSelectQuantityTitle()
    }

    var maxValue: Int {
        return TokenHolder.Tokens.count
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var stepperBorderColor: UIColor {
        return Colors.appBackground
    }

    var quantityLabelText: String {
		return R.string.localizable.aWalletTokenTokenSellQuantityTitle()
    }

    var pricePerTokenLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellPricePerTokenTitle()
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryTimeTitle()
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellTotalCostTitle()
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appText
    }

    var ethCostLabelText: String {
        return "\(ethCost) ETH"
    }

    var ethCostLabelColor: UIColor {
        return Colors.appBackground
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var dollarCostLabelText: String {
        return "$\(dollarCost)"
    }

    var dollarCostLabelColor: UIColor {
        return Colors.darkGray
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var dollarCostLabelBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var hideDollarCost: Bool {
        return dollarCost.trimmed.isEmpty
    }

    init(token: TokenObject, TokenHolder: TokenHolder) {
        self.token = token
        self.TokenHolder = TokenHolder
    }
}
