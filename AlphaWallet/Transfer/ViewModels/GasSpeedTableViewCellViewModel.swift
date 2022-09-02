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
    let cryptoToDollarRate: Double?
    let symbol: String
    var title: String
    let isSelected: Bool

    private var gasFeeString: String {
        let fee = configuration.gasPrice * configuration.gasLimit
        let feeString = EtherNumberFormatter.short.string(from: fee)
        let cryptoToDollarSymbol = Constants.Currency.usd
        if let cryptoToDollarRate = cryptoToDollarRate {
            let cryptoToDollarValue = StringFormatter().currency(with: Double(fee) * cryptoToDollarRate / Double(EthereumUnit.ether.rawValue), and: cryptoToDollarSymbol)
            return  "< ~\(feeString) \(symbol) (\(cryptoToDollarValue) \(cryptoToDollarSymbol))"
        } else {
            return "< ~\(feeString) \(symbol)"
        }
    }

    private var gasPriceString: String {
        let price = configuration.gasPrice / BigInt(EthereumUnit.gwei.rawValue)
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
                .foregroundColor: Colors.black,
                .font: Fonts.semibold(size: 17)
            ])
        } else {
            return NSAttributedString(string: title, attributes: [
                .foregroundColor: Colors.black,
                .font: Fonts.regular(size: 17)
            ])
        }
    }

    var estimatedTimeAttributedString: NSAttributedString? {
        guard let estimatedTime = estimatedTime else { return nil }

        return NSAttributedString(string: estimatedTime, attributes: [
            .foregroundColor: R.color.mine()!,
            .font: Fonts.regular(size: 15)
        ])
    }

    var detailsAttributedString: NSAttributedString? {
        return NSAttributedString(string: gasFeeString, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 15)
        ])
    }

    var gasPriceAttributedString: NSAttributedString? {
        NSAttributedString(string: gasPriceString, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)
        ])
    }

    var backgroundColor: UIColor {
        return .clear
    }
}
