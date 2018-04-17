// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ChooseTicketSellModeViewControllerViewModel {
    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }
    var titleColor: UIColor {
        return Colors.appText
    }
    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }
    var titleLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellModeChooseTitle()
    }
    var textButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellModeChooseTextTitle()
    }
    var inputWalletAddressButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellModeChooseInputWalletAddressTitle()
    }
    var inputWalletAddressButtonImage: UIImage? {
        return R.image.transfer_wallet_address()
    }
    var qrCodeScannerButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellModeChooseWalletAddressViaQRCodeScannerTitle()
    }
    var qrCodeScannerButtonImage: UIImage? {
        return R.image.transfer_qr_code()
    }
    var otherButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellModeChooseOtherTitle()
    }
    var otherButtonImage: UIImage? {
        return R.image.transfer_others()
    }
    var buttonTitleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.light(size: 18)!
        } else {
            return Fonts.light(size: 21)!
        }
    }
    var buttonTitleColor: UIColor {
        return Colors.appText
    }
}
