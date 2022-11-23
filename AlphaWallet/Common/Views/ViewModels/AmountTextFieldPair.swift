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
            case .error: return Configuration.Color.Semantic.defaultErrorText
            case .none: return Configuration.Color.Semantic.defaultForegroundText
            }
        }

        var statusLabelTextColor: UIColor {
            switch self {
            case .error: return Configuration.Color.Semantic.defaultErrorText
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
            case .error: return Configuration.Color.Semantic.defaultErrorText
            case .none: return Configuration.Color.Semantic.defaultForegroundText
            }
        }

        var textFieldPlaceholderTextColor: UIColor {
            switch self {
            case .error: return Configuration.Color.Semantic.textFieldStatus
            case .none: return Configuration.Color.Semantic.placeholderText
            }
        }
    }

    enum FiatOrCrypto {
        case cryptoCurrency(EnterAmountSupportable)
        case fiatCurrency(Currency)

        var token: EnterAmountSupportable? {
            switch self {
            case .cryptoCurrency(let token): return token
            case .fiatCurrency: return nil
            }
        }
    }

    struct Pair {
        var left: FiatOrCrypto
        var right: FiatOrCrypto

        @discardableResult mutating func swap() -> Pair {
            let currentLeft = left

            left = right
            right = currentLeft
            return self
        }

        var anyCryptoCurrency: FiatOrCrypto? {
            switch (left, right) {
            case (.cryptoCurrency, _):
                return left
            case (_, .cryptoCurrency):
                return right
            case (_, _):
                return nil
            }
        }

        @discardableResult mutating func set(token: EnterAmountSupportable) -> Pair {
            switch left {
            case .cryptoCurrency:
                self.left = .cryptoCurrency(token)
            case .fiatCurrency:
                switch right {
                case .fiatCurrency:
                    break //no-op might be two crypto
                case .cryptoCurrency:
                    self.right = .cryptoCurrency(token)
                }
            }

            return self
        }

        @discardableResult mutating func set(currency: Currency) -> Pair {
            switch left {
            case .cryptoCurrency:
                switch right {
                case .fiatCurrency:
                    self.right = .fiatCurrency(currency)
                case .cryptoCurrency:
                    break //no-op might be two crypto
                }
            case .fiatCurrency:
                self.left = .fiatCurrency(currency)
            }
            return self
        }

        var symbol: String {
            switch left {
            case .cryptoCurrency(let token): return token.symbol
            case .fiatCurrency(let currency): return currency.code
            }
        }

        var fiat: Currency {
            switch (left, right) {
            case (_, .fiatCurrency(let currency)):
                return currency
            case (.fiatCurrency(let currency), _):
                return currency
            case (_, _):
                return Currency.default
            }
        }

        var icon: Subscribable<TokenImage> {
            switch left {
            case .cryptoCurrency(let token): return token.icon(withSize: .s120)
            case .fiatCurrency(let currency):
                return .init((image: .image(currency.icon), symbol: "", isFinal: true, overlayServerIcon: nil))
            }
        }

        var token: EnterAmountSupportable? { return left.token ?? right.token }
    }
}
