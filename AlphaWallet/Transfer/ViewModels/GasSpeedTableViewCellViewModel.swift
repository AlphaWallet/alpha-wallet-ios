//
//  GasSpeedViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import BigInt
import AlphaWalletFoundation

struct GasSpeedViewModel {
    let configuration: TransactionConfiguration
    let configurationType: TransactionConfigurationType
    let rate: CurrencyRate?
    let symbol: String
    var title: String
    let isSelected: Bool

    private var gasFeeString: String {
        let fee = configuration.gasPrice * configuration.gasLimit
        let feeString = EtherNumberFormatter.short.string(from: fee)
        if let rate = rate {
            let cryptoToDollarValue = StringFormatter().currency(with: Double(fee) * rate.value / Double(EthereumUnit.ether.rawValue), and: rate.currency.code)
            return  "< ~\(feeString) \(symbol) (\(cryptoToDollarValue) \(rate.currency.code))"
        } else {
            return "< ~\(feeString) \(symbol)"
        }
    }

    private var gasPriceString: String {
        let price = configuration.gasPrice / BigUInt(EthereumUnit.gwei.rawValue)
        return "\(R.string.localizable.configureTransactionHeaderGasPrice()): \(price) \(EthereumUnit.gwei.name)"
    }

    private var estimatedTime: String? {
        let estimatedProcessingTime = configurationType.estimatedProcessingTime
        if estimatedProcessingTime.isEmpty {
            return nil
        } else {
            return estimatedProcessingTime
        }
    }

    var accessoryIcon: UIImage? {
        return isSelected ? R.image.iconsCheckmark() : .none
    }

    var titleAttributedString: NSAttributedString? {
        if isSelected {
            return NSAttributedString(string: title, attributes: [
                .foregroundColor: Configuration.Color.Semantic.defaultTitleText,
                .font: Fonts.semibold(size: 17)
            ])
        } else {
            return NSAttributedString(string: title, attributes: [
                .foregroundColor: Configuration.Color.Semantic.defaultTitleText,
                .font: Fonts.regular(size: 17)
            ])
        }
    }

    var estimatedTimeAttributedString: NSAttributedString? {
        guard let estimatedTime = estimatedTime else { return nil }

        return NSAttributedString(string: estimatedTime, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultHeadlineText,
            .font: Fonts.regular(size: 15)
        ])
    }

    var detailsAttributedString: NSAttributedString? {
        return NSAttributedString(string: gasFeeString, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 15)
        ])
    }

    var gasPriceAttributedString: NSAttributedString? {
        NSAttributedString(string: gasPriceString, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 13)
        ])
    }

    var backgroundColor: UIColor {
        return .clear
    }
}
