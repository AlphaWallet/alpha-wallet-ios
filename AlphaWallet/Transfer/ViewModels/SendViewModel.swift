// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore

struct SendViewModel {
    private let transferType: TransferType
    private let session: WalletSession
    private let storage: TokensDataStore

    init(transferType: TransferType, session: WalletSession, storage: TokensDataStore) {
        self.transferType = transferType
        self.session = session
        self.storage = storage
    }

    var destinationAddress: Address {
        return transferType.contract()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var token: TokenObject? {
        switch transferType {
        case .ether(destination: _):
            return nil
        case .ERC20Token(let token):
            return token
        case .ERC875Token(let token):
            return token
        case .ERC875TokenOrder(let token):
            return token
        case .ERC721Token(let token):
            return token
        case .dapp:
            return nil
        }
    }

    var showAlternativeAmount: Bool {
        guard let currentTokenInfo = storage.tickers?[destinationAddress.description], let price = Double(currentTokenInfo.price_usd), price > 0 else {
            return false
        }
        return true
    }

    var myAddressText: String {
        return session.account.address.description
    }
    var addressFont: UIFont {
        return Fonts.semibold(size: 14)!
    }
    var addressCopiedText: String {
        return R.string.localizable.requestAddressCopiedTitle()
    }

    var copyAddressButtonBackgroundColor: UIColor {
        return Colors.appBackground
    }
    var copyAddressButtonTitleColor: UIColor {
        return Colors.appWhite
    }
    var copyAddressButtonFont: UIFont {
        return Fonts.regular(size: 14)!
    }
    var copyAddressButtonTitle: String {
        return R.string.localizable.copy()
    }
    var textFieldsLabelTextColor: UIColor {
        return Colors.appGrayLabelColor
    }
    var textFieldsLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var myAddressTextColor: UIColor {
        return Colors.gray
    }
    var myAddressBorderColor: UIColor {
        return UIColor(red: 235, green: 235, blue: 235)
    }
    var myAddressBorderWidth: CGFloat {
        return 1
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
}
