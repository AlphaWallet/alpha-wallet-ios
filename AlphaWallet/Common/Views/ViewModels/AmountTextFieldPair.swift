//
//  AmountTextFieldPair.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.03.2022.
//

import UIKit
import AlphaWalletFoundation

extension AmountTextField {
    enum AccessoryButtonTitle {
        case done
        case next

        var buttonTitle: String {
            switch self {
            case .done: return R.string.localizable.done()
            case .next: return R.string.localizable.next()
            }
        }
    }

    enum ErrorState: Error {
        case error
        case none

        var textColor: UIColor {
            switch self {
            case .error: return DataEntry.Color.textFieldStatus!
            case .none: return Configuration.Color.Semantic.defaultForegroundText
            }
        }

        var statusLabelTextColor: UIColor {
            switch self {
            case .error: return DataEntry.Color.textFieldStatus!
            case .none: return Configuration.Color.Semantic.defaultSubtitleText
            }
        }

        var statusLabelFont: UIFont {
            switch self {
            case .error: return Fonts.semibold(size: 13)
            case .none: return Fonts.regular(size: 13)
            }
        }

        var textFieldTextColor: UIColor {
            switch self {
            case .error: return DataEntry.Color.textFieldStatus!
            case .none: return Configuration.Color.Semantic.defaultForegroundText
            }
        }

        var textFieldPlaceholderTextColor: UIColor {
            switch self {
            case .error: return DataEntry.Color.textFieldStatus!
            case .none: return Configuration.Color.Semantic.placeholderText
            }
        }
    }

    enum FiatOrCrypto {
        case cryptoCurrency(Token)
        case fiatCurrency(Currency)

        var token: Token? {
            switch self {
            case .cryptoCurrency(let token): return token
            case .fiatCurrency: return nil
            }
        }
    }

    struct Pair {
        var left: FiatOrCrypto
        var right: FiatOrCrypto

        mutating func swap() {
            let currentLeft = left

            left = right
            right = currentLeft
        }

        var symbol: String {
            switch left {
            case .cryptoCurrency(let token): return token.symbol
            case .fiatCurrency: return Currency.USD.rawValue
            }
        }

        var fiat: Currency {
            switch (left, right) {
            case (_, .fiatCurrency(let currency)):
                return currency
            case (.fiatCurrency(let currency), _):
                return currency
            case (_, _):
                return .USD
            }
        }

        var icon: Subscribable<TokenImage> {
            switch left {
            case .cryptoCurrency(let token): return token.icon(withSize: .s120)
            case .fiatCurrency:
                return .init((image: .image(R.image.usaFlag()!), symbol: "", isFinal: true, overlayServerIcon: nil))
            }
        }

        var token: Token? { return left.token ?? right.token }
    }
}
