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
        case .ERC721ForTicketToken(let token):
            return token
        case .dapp:
            return nil
        }
    }

    var showAlternativeAmount: Bool {
        guard let currentTokenInfo = storage.tickers?[destinationAddress], currentTokenInfo.price_usd > 0 else {
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

    var recepientLabelFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var recepientLabelTextColor: UIColor {
        return R.color.dove()!
    }

    var recipientsAddress: String {
        return R.string.localizable.sendRecipientsAddress()
    }

    var amountTextFieldPair: AmountTextField.Pair {
        switch transferType {
        case .nativeCryptocurrency, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            switch session.server {
            case .xDai:
                return AmountTextField.Pair(left: .cryptoCurrency("xDAI", R.image.xDai()!), right: .usd("USD"))
            case .rinkeby, .ropsten, .main, .custom, .callisto, .classic, .kovan, .sokol, .poa, .goerli, .artis_sigma1, .artis_tau1:
                return AmountTextField.Pair(left: .cryptoCurrency("ETH", R.image.eth()!), right: .usd("USD"))
            }
        case .ERC20Token:
            return AmountTextField.Pair(left: .cryptoCurrency(transferType.symbol, R.image.ethSmall()!))
        }
    }

    var isAlternativeAmountEnabled: Bool {
        switch transferType {
        case .nativeCryptocurrency:
            return true
        case .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            return false
        }
    }

    var selectCurrencyButtonHidden: Bool {
        switch transferType {
        case .nativeCryptocurrency, .ERC20Token:
            return false
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            return true
        }
    }
}
