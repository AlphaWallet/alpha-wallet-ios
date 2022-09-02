//
//  WalletSummaryViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct WalletSummaryViewModel {
    private let alignment: NSTextAlignment
    private var areTestnetsEnabled: Bool {
        config.enabledServers.allSatisfy { $0.isTestnet }
    }
    private let config: Config
    private let walletSummary: WalletSummary

    init(walletSummary: WalletSummary, config: Config, alignment: NSTextAlignment = .left) {
        self.walletSummary = walletSummary
        self.alignment = alignment
        self.config = config
    }

    var balanceAttributedString: NSAttributedString {
        createbalanceAttributedString(summary: walletSummary)
    }

    var apprecation24HoursAttributedString: NSAttributedString {
        createApprecationAttributedString(summary: walletSummary)
    }

    private func createbalanceAttributedString(summary: WalletSummary) -> NSAttributedString {
        if areTestnetsEnabled {
            return .init(string: "Testnet", attributes: Self.functional.walletBalanceAttributes(alignment: alignment))
        } else {
            return .init(string: summary.totalAmount, attributes: Self.functional.walletBalanceAttributes(alignment: alignment))
        }
    }

    private func createApprecationAttributedString(summary: WalletSummary) -> NSAttributedString {
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
        return Configuration.Color.Semantic.defaultViewBackground
    }
}

extension WalletSummaryViewModel {
    class functional {
        static func walletBalanceAttributes(alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment

            return [
                .font: Fonts.bold(size: 36),
                .foregroundColor: Configuration.Color.Semantic.labelTextActive,
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
                    return Formatter.priceChange.string(from: value) ?? "-"
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

extension BalanceHelper {
    func valueChangeValueColor(from value: Double?) -> UIColor {
        switch change24h(from: value) {
        case .appreciate:
            return Colors.appHighlightGreen
        case .depreciate:
            return Colors.apprecationRed
        case .none:
            return Colors.appGrayLabel
        }
    }
}
