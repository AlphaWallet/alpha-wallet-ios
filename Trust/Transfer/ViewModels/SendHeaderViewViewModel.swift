// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct SendHeaderViewViewModel {
    var title = ""

    var issuer: String {
        return ""
    }

    var blockChainName: String {
        return "Ethereum Blockchain"
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }
    
    var borderColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var textColor: UIColor {
        return UIColor(red: 155, green: 155, blue: 155)
    }

    var valuePercentageChangeColor: UIColor {
        //TODO must have a different color when depreciate?
        return Colors.appHighlightGreen
    }

    var textValueFont: UIFont {
        return Fonts.semibold(size: 15)!
    }

    var textLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var valuePercentageChangeValue: String {
        //TODO read from model
//        return "+50%"
        return "N/A"
    }

    var valuePercentageChangePeriod: String {
        return R.string.localizable.aWalletContentsValuePeriodTitle()
    }

    var valueChange: String {
        //TODO read from model
//        return "$17,000"
        return "N/A"
    }

    var valueChangeName: String {
        return R.string.localizable.aWalletContentsValueAppreciationTitle()
    }

    var value: String {
        //TODO read from model
        return "N/A"
    }

    var valueName: String {
        return R.string.localizable.aWalletContentsValueDollarTitle()
    }
}
