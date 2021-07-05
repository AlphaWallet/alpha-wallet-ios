//
//  WalletSummaryTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.06.2021.
//

import UIKit

struct WalletSummaryTableViewCellViewModel {
    private let summary: WalletSummary?

    init(summary: WalletSummary?) {
        self.summary = summary
    }

    var balanceAttributedString: NSAttributedString {
        return .init(string: summary?.totalAmount ?? "--", attributes: [
            .font: Fonts.bold(size: 36),
            .foregroundColor: Colors.black,
        ])
    }

    var apprecation24HoursAttributedString: NSAttributedString {
        let apprecation = todaysApprecation
        return .init(string: apprecation.0, attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: apprecation.1,
        ])
    }

    private var todaysApprecation: (String, UIColor) {
        let valueChangeValue: String = {
            if let value = summary?.changeDouble {
                return NumberFormatter.usd.string(from: value) ?? "-"
            } else {
                return "-"
            }
        }()

        var valuePercentageChangeValue: String {
            switch BalanceHelper().change24h(from: summary?.changePercentage) {
            case .appreciate(let percentageChange24h):
                return "(+ \(percentageChange24h)%)"
            case .depreciate(let percentageChange24h):
                return "(\(percentageChange24h)%)"
            case .none:
                return "-"
            }
        }
        
        let value = R.string.localizable.walletSummaryToday(valueChangeValue + " " + valuePercentageChangeValue)
        return (value, BalanceHelper().valueChangeValueColor(from: summary?.changePercentage))
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

}


