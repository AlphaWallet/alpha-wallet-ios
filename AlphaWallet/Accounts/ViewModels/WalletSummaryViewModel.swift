//
//  WalletSummaryViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2021.
//

import UIKit

struct WalletSummaryViewModel {
    private let summary: WalletSummary?
    private let alignment: NSTextAlignment
    private var areTestnetsEnabled: Bool {
        config.enabledServers.allSatisfy { $0.isTestnet }
    }
    private let config: Config

    init(summary: WalletSummary?, config: Config, alignment: NSTextAlignment = .left) {
        self.summary = summary
        self.alignment = alignment
        self.config = config
    }

    var balanceAttributedString: NSAttributedString {
        if areTestnetsEnabled {
            return .init(string: "Testnet", attributes: Self.functional.walletBalanceAttributes(alignment: alignment))
        } else {
            return .init(string: summary?.totalAmount ?? "--", attributes: Self.functional.walletBalanceAttributes(alignment: alignment))
        }
    }

    var apprecation24HoursAttributedString: NSAttributedString {
        if areTestnetsEnabled {
            return .init(string: "Testnet Mode", attributes: Self.functional.apprecation24HoursAttributes(alignment: alignment, foregroundColor: .gray))
        } else {
            let apprecation = Self.functional.todaysApprecationColorAndStringValuePair(summary: summary)
            return .init(string: apprecation.0, attributes: Self.functional.apprecation24HoursAttributes(alignment: alignment, foregroundColor: apprecation.1))
        }
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }
}

extension WalletSummaryViewModel {
    class functional {
        static func walletBalanceAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment

            return [
                .font: Fonts.bold(size: 36),
                .foregroundColor: Colors.black,
                .paragraphStyle: style,
            ]
        }

        static func apprecation24HoursAttributes(alignment: NSTextAlignment = .left, foregroundColor: UIColor) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment

            return [
                .font: Fonts.regular(size: 20),
                .foregroundColor: foregroundColor,
                .paragraphStyle: style,
            ]
        }

        static func todaysApprecationColorAndStringValuePair(summary: WalletSummary?) -> (String, UIColor) {
            let valueChangeValue: String = {
                if let value = summary?.changeDouble {
                    return NumberFormatter.usd(format: .priceChangeFormat).string(from: value) ?? "-"
                } else {
                    return "-"
                }
            }()

            var valuePercentageChangeValue: String {
                switch BalanceHelper().change24h(from: summary?.changePercentage) {
                case .appreciate(let percentageChange24h):
                    return "(+\(percentageChange24h)%)"
                case .depreciate(let percentageChange24h):
                    return "(\(percentageChange24h)%)"
                case .none:
                    return "-"
                }
            }

            let value = R.string.localizable.walletSummaryToday(valueChangeValue + " " + valuePercentageChangeValue)
            return (value, BalanceHelper().valueChangeValueColor(from: summary?.changePercentage))
        }
    }
}
