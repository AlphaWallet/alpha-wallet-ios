//
//  SelectableSwapRouteTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.09.2022.
//

import UIKit
import AlphaWalletFoundation
import BigInt

struct SelectableSwapRouteTableViewCellViewModel: Hashable {
    private let exchange: String
    private let tag: String
    private let fees: [String]
    private let amount: Decimal
    private let toTokenRpcServer: RPCServer
    private let toTokenSymbol: String
    private let isSelected: Bool
    private static let formatter: EtherNumberFormatter = .plain

    let selectionStyle: UITableViewCell.SelectionStyle = .default

    var accessoryImage: UIImage? {
        return isSelected ? R.image.iconsSystemCheckboxOn() : R.image.iconsSystemCheckboxOff()
    }

    var swapViaExchangeAttributedString: NSAttributedString {
        return NSAttributedString(string: exchange, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Fonts.regular(size: 18)
        ])
    }

    var tokenRpcServerImage: UIImage? {
        toTokenRpcServer.iconImage
    }

    var amountAttributedString: NSAttributedString {
        let string = NumberFormatter.shortCrypto.string(double: amount.doubleValue, minimumFractionDigits: 6, maximumFractionDigits: 8)
        return NSAttributedString(string: "\(string) \(toTokenSymbol)", attributes: [
            .foregroundColor: Configuration.Color.Semantic.alternativeText,
            .font: Fonts.bold(size: 20)
        ])
    }

    var tagAttributedString: NSAttributedString {
        return NSAttributedString(string: tag, attributes: [
            .foregroundColor: Configuration.Color.Semantic.appTint,
            .font: Fonts.bold(size: 14)
        ])
    }

    var feesAttributedStrings: [NSAttributedString] {
        return fees.map { value -> NSAttributedString in
            return NSAttributedString(string: value, attributes: [
                .foregroundColor: Configuration.Color.Semantic.alternativeText,
                .font: Fonts.regular(size: 16)
            ])
        }
    }

    init(swapRoute: SwapRoute, isSelected: Bool) {
        self.isSelected = isSelected
        self.toTokenSymbol = swapRoute.toToken.symbol
        self.toTokenRpcServer = RPCServer(chainID: swapRoute.toToken.chainId)
        self.tag = swapRoute.tags.first ?? ""
        self.exchange = swapRoute.steps.first.flatMap { "Swap via \($0.tool)" } ?? "-"
        self.amount = Decimal(bigUInt: swapRoute.toAmount, decimals: swapRoute.toToken.decimals) ?? .zero
        self.fees = swapRoute.steps.map { step -> [String] in
            let gasCosts = step.estimate.gasCosts.map { gasCost -> String in
                let toAmount = Decimal(bigUInt: gasCost.amount, decimals: gasCost.token.decimals) ?? .zero
                let string = NumberFormatter.shortCrypto.string(double: toAmount.doubleValue, minimumFractionDigits: 6, maximumFractionDigits: 8)
                return "Gas Fee:" + " " + "\(string) \(gasCost.token.symbol)"
            }
            let fees = step.estimate.feeCosts.map { feeCost -> String in
                let feeAmount = Decimal(bigUInt: feeCost.amount, decimals: feeCost.token.decimals) ?? .zero
                let string = NumberFormatter.shortCrypto.string(double: feeAmount.doubleValue, minimumFractionDigits: 6, maximumFractionDigits: 8)
                return "\(feeCost.name):" + " " + "\(string) \(feeCost.token.symbol)"
            }
            return gasCosts + fees
        }.flatMap { $0 }
    }
}
