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
    private let amount: String
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
        return NSAttributedString(string: "\(amount) \(toTokenSymbol)", attributes: [
            .foregroundColor: Configuration.Color.Semantic.alternativeText,
            .font: Fonts.bold(size: 20)
        ])
    }

    var tagAttributedString: NSAttributedString {
        return NSAttributedString(string: tag, attributes: [
            .foregroundColor: Colors.appTint,
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
        self.amount = SelectableSwapRouteTableViewCellViewModel.formatter.string(from: swapRoute.toAmount, decimals: swapRoute.toToken.decimals)
        self.fees = swapRoute.steps.map { step -> [String] in
            let gasCosts = step.estimate.gasCosts.map { gasCost -> String in
                let toAmount = SelectableSwapRouteTableViewCellViewModel.formatter.string(from: gasCost.amount, decimals: gasCost.token.decimals)
                return "Gas Fee:" + " " + "\(toAmount) \(gasCost.token.symbol)"
            }
            let fees = step.estimate.feeCosts.map { feeCost -> String in
                let toAmount = SelectableSwapRouteTableViewCellViewModel.formatter.string(from: feeCost.amount, decimals: feeCost.token.decimals)
                return "\(feeCost.name):" + " " + "\(toAmount) \(feeCost.token.symbol)"
            }
            return gasCosts + fees
        }.flatMap { $0 }
    }
}
