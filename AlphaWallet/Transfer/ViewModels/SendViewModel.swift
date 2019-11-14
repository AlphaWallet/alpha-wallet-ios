// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SendViewModel {
    private let session: WalletSession
    private let storage: TokensDataStore

    let transferType: TransferType

    init(transferType: TransferType, session: WalletSession, storage: TokensDataStore) {
        self.transferType = transferType
        self.session = session
        self.storage = storage
    }

    var destinationAddress: AlphaWallet.Address {
        return transferType.contract
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var token: TokenObject? {
        switch transferType {
        case .nativeCryptocurrency:
            return nil
        case .ERC20Token(let token, _, _):
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
        guard let currentTokenInfo = storage.tickers?[destinationAddress], let price = Double(currentTokenInfo.price_usd), price > 0 else {
            return false
        }
        return true
    }

    var textFieldsLabelTextColor: UIColor {
        return Colors.appGrayLabel
    }
    var textFieldsLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }
}
