// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ChooseTicketTransferModeViewControllerViewModel {
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
        return R.string.localizable.aWalletTicketTokenTransferModeChooseTitle()
    }
    var textButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferModeChooseTextTitle()
    }
    var textButtonImage: UIImage? {
        return R.image.transfer_text()
    }
    var emailButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferModeChooseEmailTitle()
    }
    var emailButtonImage: UIImage? {
        return R.image.transfer_email()
    }
    var inputWalletAddressButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferModeChooseInputWalletAddressTitle()
    }
    var inputWalletAddressButtonImage: UIImage? {
        return R.image.transfer_wallet_address()
    }
    var qrCodeScannerButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferModeChooseWalletAddressViaQRCodeScannerTitle()
    }
    var qrCodeScannerButtonImage: UIImage? {
        return R.image.transfer_qr_code()
    }
    var otherButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferModeChooseOtherTitle()
    }
    var otherButtonImage: UIImage? {
        return R.image.transfer_others()
    }
    var buttonTitleFont: UIFont {
        return Fonts.light(size: 21)!
    }
    var buttonTitleColor: UIColor {
        return Colors.appText
    }
}
