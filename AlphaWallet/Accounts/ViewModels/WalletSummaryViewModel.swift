//
//  WalletSummaryViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct WalletSummaryViewModel: Hashable {
    private let alignment: NSTextAlignment
    private let walletSummary: WalletSummary

    init(walletSummary: WalletSummary, alignment: NSTextAlignment = .left) {
        self.walletSummary = walletSummary
        self.alignment = alignment
    }

    var balanceAttributedString: NSAttributedString {
        createbalanceAttributedString(summary: walletSummary)
    }

    var apprecation24HoursAttributedString: NSAttributedString {
        createApprecationAttributedString(summary: walletSummary)
    }

    private func createbalanceAttributedString(summary: WalletSummary) -> NSAttributedString {
        return .init(string: summary.totalAmountString, attributes: functional.walletBalanceAttributes(alignment: alignment))
    }

    private func createApprecationAttributedString(summary: WalletSummary) -> NSAttributedString {
        let apprecation = functional.todaysApprecationColorAndStringValuePair(summary: summary)
        return .init(string: apprecation.0, attributes: functional.apprecation24HoursAttributes(alignment: alignment, foregroundColor: apprecation.1))
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }
}

extension WalletSummaryViewModel {
    enum functional {
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
            let helper = TickerHelper(ticker: nil)

            let changeString = summary.flatMap {
                $0.change.flatMap { NumberFormatter.priceChange(currency: $0.currency).string(double: $0.amount) }
            } ?? "-"

            let changePercentage: String = {
                guard let changePercentage = summary?.changePercentage else { return "-" }
                let formatter = NumberFormatter.percent

                switch helper.change24h(from: changePercentage.amount) {
                case .appreciate(let percentageChange24h):
                    return "\(formatter.string(double: percentageChange24h) ?? "")%"
                case .depreciate(let percentageChange24h):
                    return "\(formatter.string(double: percentageChange24h) ?? "")%"
                case .none:
                    return "-"
                }
            }()

            let value = R.string.localizable.walletSummaryToday(changeString + " " + changePercentage)
            return (value, helper.valueChangeValueColor(from: summary?.changePercentage?.amount))
        }
    }
}

extension TickerHelper {
    func valueChangeValueColor(from value: Double?) -> UIColor {
        switch change24h(from: value) {
        case .appreciate:
            return Configuration.Color.Semantic.appreciation
        case .depreciate:
            return Configuration.Color.Semantic.depreciation
        case .none:
            return Configuration.Color.Semantic.defaultSubtitleText
        }
    }
}
