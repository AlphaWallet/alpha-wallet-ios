//
//  GasSpeedViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import BigInt
import AlphaWalletFoundation

struct LegacyGasSpeedViewModel: GasSpeedViewModelType {
    let gasPrice: BigUInt
    let gasLimit: BigUInt
    let gasSpeed: GasSpeed
    let rate: CurrencyRate?
    let symbol: String
    let isSelected: Bool
    let isHidden: Bool
    
    private var gasFeeString: String {
        let fee = Decimal(bigUInt: gasPrice * gasLimit, units: .ether) ?? .zero
        let feeString = NumberFormatter.shortCrypto.string(decimal: fee) ?? ""
        if let rate = rate {
            let cryptoToDollarValue = StringFormatter().currency(with: fee.doubleValue * rate.value, and: rate.currency.code)
            return  "< ~\(feeString) \(symbol) (\(cryptoToDollarValue) \(rate.currency.code))"
        } else {
            return "< ~\(feeString) \(symbol)"
        }
    }

    private var gasPriceString: String {
        let price = Decimal(bigUInt: gasPrice, units: .gwei) ?? .zero
        return "\(R.string.localizable.configureTransactionHeaderGasPrice()): \(String(price.doubleValue)) \(EthereumUnit.gwei.name)"
    }

    private var estimatedTime: String? {
        let estimatedProcessingTime = gasSpeed.estimatedProcessingTime
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
        return NSAttributedString(string: gasSpeed.title, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultTitleText,
            .font: isSelected ? Fonts.semibold(size: 17) : Fonts.regular(size: 17)
        ])
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
}

struct UnavailableGasSpeedViewModel: GasSpeedViewModelType {
    let gasSpeed: GasSpeed
    let isSelected: Bool
    let isHidden: Bool

    var accessoryIcon: UIImage? {
        return isSelected ? R.image.iconsCheckmark() : .none
    }

    var titleAttributedString: NSAttributedString? {
        return NSAttributedString(string: gasSpeed.title, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultTitleText,
            .font: isSelected ? Fonts.semibold(size: 17) : Fonts.regular(size: 17)
        ])
    }

    var estimatedTimeAttributedString: NSAttributedString? {
        return nil
    }

    var detailsAttributedString: NSAttributedString? {
        return nil
    }

    var gasPriceAttributedString: NSAttributedString? {
        return nil
    }
}
