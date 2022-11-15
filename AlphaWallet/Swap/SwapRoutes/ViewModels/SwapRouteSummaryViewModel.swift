//
//  SwapRouteSummaryViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.09.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct SwapRouteSummaryViewModelInput {

}

struct SwapRouteSummaryViewModelOutput {
    let viewState: AnyPublisher<SwapRouteSummaryViewModel.ViewState, Never>
}

final class SwapRouteSummaryViewModel {
    private let etherFormatter: EtherNumberFormatter = .plain
    private let route: AnyPublisher<SwapRoute?, Never>
    private let decimalParser = DecimalParser()
    let backgroundColor: UIColor = Colors.appBackground

    init(route: AnyPublisher<SwapRoute?, Never>) {
        self.route = route
    }

    func transform(input: SwapRouteSummaryViewModelInput) -> SwapRouteSummaryViewModelOutput {
        let viewState = route.map { route -> SwapRouteSummaryViewModel.ViewState in
            let serverImage = route.flatMap { RPCServer(chainID: $0.toToken.chainId).iconImage }
            return .init(serverImage: serverImage, amountToHeader: self.amountToHeader, amountTo: self.amountTo(for: route), currentPriceHeader: self.currentPriceHeader, currentPrice: self.currentPrice(for: route))
        }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private var currentPriceHeader: NSAttributedString {
        return .init(string: "Current Price", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: Colors.darkGray
        ])
    }

    private var amountToHeader: NSAttributedString {
        return .init(string: "Amount To Swap", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: Colors.darkGray
        ])
    }

    private func currentPrice(for swapRoute: SwapRoute?) -> NSAttributedString {
        let currentPrice = swapRoute.flatMap { route in
            let toAmount = etherFormatter.string(from: route.toAmount, decimals: route.toToken.decimals)
            let fromAmount = etherFormatter.string(from: route.fromAmount, decimals: route.fromToken.decimals)

            guard
                let toAmount = decimalParser.parseAnyDecimal(from: toAmount)?.doubleValue,
                let fromAmount = decimalParser.parseAnyDecimal(from: fromAmount)?.doubleValue
            else { return "-" }

            let rate: Double? = {
                guard fromAmount > 0 else { return nil }
                return (toAmount / fromAmount).nilIfNan
            }()
            guard let cryptoToCryptoRate = rate.flatMap({ Formatter.shortCrypto(symbol: route.toToken.symbol).string(from: $0) }) else { return "-" }

            return "1 \(route.fromToken.symbol) = \(cryptoToCryptoRate)"
        } ?? "-"

        return .init(string: currentPrice, attributes: [
            .font: Fonts.semibold(size: 16),
            .foregroundColor: Colors.darkGray
        ])
    }

    private func amountTo(for swapRoute: SwapRoute?) -> NSAttributedString {
        let amountTo = swapRoute.flatMap { route -> String? in
            let fromAmount = EtherNumberFormatter.plain.string(from: route.fromAmount, decimals: route.fromToken.decimals)
            return "\(fromAmount) \(route.fromToken.symbol)"
        } ?? "-"

        return .init(string: amountTo, attributes: [
            .font: Fonts.semibold(size: 16),
            .foregroundColor: Colors.darkGray
        ])
    }
}

extension SwapRouteSummaryViewModel {
    struct ViewState {
        let serverImage: UIImage?
        let amountToHeader: NSAttributedString
        let amountTo: NSAttributedString
        let currentPriceHeader: NSAttributedString
        let currentPrice: NSAttributedString
    }
}
