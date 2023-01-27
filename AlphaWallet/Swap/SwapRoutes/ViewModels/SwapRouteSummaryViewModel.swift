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
    private let route: AnyPublisher<SwapRoute?, Never>

    init(route: AnyPublisher<SwapRoute?, Never>) {
        self.route = route
    }

    func transform(input: SwapRouteSummaryViewModelInput) -> SwapRouteSummaryViewModelOutput {
        let viewState = route.map { route -> SwapRouteSummaryViewModel.ViewState in
            let serverImage = route.flatMap { RPCServer(chainID: $0.toToken.chainId).iconImage }
            return .init(
                serverImage: serverImage,
                amountToHeader: self.amountToHeader,
                amountTo: self.amountTo(for: route),
                currentPriceHeader: self.currentPriceHeader,
                currentPrice: self.currentPrice(for: route))
        }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private var currentPriceHeader: NSAttributedString {
        return .init(string: "Current Price", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: Configuration.Color.Semantic.alternativeText
        ])
    }

    private var amountToHeader: NSAttributedString {
        return .init(string: "Amount To Swap", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: Configuration.Color.Semantic.alternativeText
        ])
    }

    private func currentPrice(for swapRoute: SwapRoute?) -> NSAttributedString {
        guard let route = swapRoute else { return attributedValue("-") }

        let toAmount = Decimal(bigUInt: route.toAmount, decimals: route.toToken.decimals)
        let fromAmount = Decimal(bigUInt: route.fromAmount, decimals: route.fromToken.decimals)

        guard let toAmount = toAmount, let fromAmount = fromAmount else { return attributedValue("-") }
        guard fromAmount > 0, let rate = (toAmount / fromAmount).nilIfNan else { return attributedValue("-") }

        let string = NumberFormatter.shortCrypto.string(double: rate.doubleValue, minimumFractionDigits: 2, maximumFractionDigits: 4).droppedTrailingZeros

        let currentPrice = "1 \(route.fromToken.symbol) = \(string) \(route.toToken.symbol)"

        return attributedValue(currentPrice)
    }

    private func amountTo(for swapRoute: SwapRoute?) -> NSAttributedString {
        guard let route = swapRoute else { return attributedValue("-") }

        let fromAmount = Decimal(bigUInt: route.fromAmount, decimals: route.fromToken.decimals) ?? .zero
        let string = NumberFormatter.shortCrypto.string(double: fromAmount.doubleValue, minimumFractionDigits: 6, maximumFractionDigits: 8).droppedTrailingZeros

        let amountTo = "\(string) \(route.fromToken.symbol)"

        return attributedValue(amountTo)
    }

    private func attributedValue(_ string: String) -> NSAttributedString {
        return .init(string: string, attributes: [
            .font: Fonts.semibold(size: 16),
            .foregroundColor: Configuration.Color.Semantic.alternativeText
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
