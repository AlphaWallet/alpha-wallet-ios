//
//  Eip1559GasSpeedViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation

struct Eip1559GasSpeedViewModel: GasSpeedViewModelType {
    let gasSpeed: GasSpeed
    let maxFeePerGas: BigUInt
    let maxPriorityFeePerGas: BigUInt
    let gasLimit: BigUInt
    let rate: CurrencyRate?
    let symbol: String
    var title: String { gasSpeed.title }
    let isSelected: Bool
    let isHidden: Bool

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
        return NSAttributedString(string: title, attributes: [
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
        let fee = Decimal(bigUInt: maxFeePerGas * gasLimit, units: .ether) ?? .zero
        let feeString = NumberFormatter.shortCrypto.string(
            double: fee.doubleValue,
            minimumFractionDigits: 4,
            maximumFractionDigits: 8)

        let string: String
        if let rate = rate {
            let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(
                double: fee.doubleValue * rate.value,
                minimumFractionDigits: 2,
                maximumFractionDigits: 6)
            
            string = "< ~\(feeString) \(symbol) (\(amountInFiat))"
        } else {
            string = "< ~\(feeString) \(symbol)"
        }

        return NSAttributedString(string: string, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 15)
        ])
    }

    var gasPriceAttributedString: NSAttributedString? {
        let maxFeePerGas = Decimal(bigUInt: maxFeePerGas, units: .gwei) ?? .zero
        let maxPriorityFeePerGas = Decimal(bigUInt: maxPriorityFeePerGas, units: .gwei) ?? .zero
        let maxFeePerGasValueString = NumberFormatter.value().string(decimal: maxFeePerGas) ?? ""

        let maxPriorityFeePerGasString = NumberFormatter.shortCrypto.string(
            double: maxPriorityFeePerGas.doubleValue,
            minimumFractionDigits: 4,
            maximumFractionDigits: 8)

        let s1 = propertyName(placeholder: R.string.localizable.configureTransactionHeaderMaxFee() + ": ") + value(value: "\(maxFeePerGasValueString) \(EthereumUnit.gwei.name)")

        let s2 = propertyName(placeholder: R.string.localizable.configureTransactionHeaderMaxPriorityFee() + ": ") + value(value: "\(maxPriorityFeePerGasString) \(EthereumUnit.gwei.name)")

        return s1 + value(value: "   ") + s2
    }

    private func value(value: String) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 13)
        ])
    }

    private func propertyName(placeholder: String) -> NSAttributedString {
        return NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultTitleText,
            .font: isSelected ? Fonts.semibold(size: 13) : Fonts.regular(size: 13)
        ])
    }
}
