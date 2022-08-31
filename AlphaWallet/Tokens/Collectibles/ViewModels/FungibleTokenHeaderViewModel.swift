//
//  FungibleTokenHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.05.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct FungibleTokenHeaderViewModelInput {
    let toggleValue: AnyPublisher<Void, Never>
}

struct FungibleTokenHeaderViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenHeaderViewModel.ViewState, Never>
}

final class FungibleTokenHeaderViewModel {
    private let headerViewRefreshInterval: TimeInterval = 5.0
    private var headerRefreshTimer: Timer?
    private let transactionType: TransactionType
    private var isShowingValueSubject: CurrentValueSubject<Bool, Never> = .init(true)
    private lazy var tokenViewModel: AnyPublisher<TokenViewModel?, Never> = {
        switch transactionType {
        case .nativeCryptocurrency:
            let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionType.server)
            return service.tokenViewModelPublisher(for: etherToken)
                .eraseToAnyPublisher()
        case .erc20Token(let token, _, _):
            return service.tokenViewModelPublisher(for: token)
                .eraseToAnyPublisher()
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return Just<TokenViewModel?>(nil)
                .eraseToAnyPublisher()
        }
    }()
    private let service: TokenViewModelState
    private var cancelable = Set<AnyCancellable>()

    var server: RPCServer { return transactionType.tokenObject.server }
    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }
    var iconImage: Subscribable<TokenImage> {
        transactionType.tokenObject.icon(withSize: .s300)
    }
    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: transactionType.tokenObject.server)
    }

    init(transactionType: TransactionType, service: TokenViewModelState) {
        self.transactionType = transactionType
        self.service = service
    }

    deinit {
        invalidateRefreshHeaderTimer()
    }

    func transform(input: FungibleTokenHeaderViewModelInput) -> FungibleTokenHeaderViewModelOutput {
        runRefreshHeaderTimer()

        input.toggleValue.sink { [weak self] in
            self?.tiggleIsShowingValue()
            self?.invalidateRefreshHeaderTimer()
            self?.runRefreshHeaderTimer()
        }.store(in: &cancelable)

        let tokenViewModel = tokenViewModel.combineLatest(isShowingValueSubject, { balance, _ in return balance })

        let title = tokenViewModel.map { [weak self] token -> NSAttributedString in
            guard let strongSelf = self, let token = token else { return .init(string: UiTweaks.noPriceMarker) }
            let value: String
            switch strongSelf.transactionType {
            case .nativeCryptocurrency:
                value = "\(token.balance.amountShort) \(token.balance.symbol)"
            case .erc20Token:
                value = "\(token.balance.amountShort) \(token.tokenScriptOverrides?.symbolInPluralForm ?? token.balance.symbol)"
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                value = UiTweaks.noPriceMarker
            }

            return strongSelf.asTitleAttributedString(value)
        }
        
        let value = tokenViewModel.map { $0?.balance }
            .map { [weak self] balance -> NSAttributedString in
                guard let strongSelf = self, let balance = balance else { return .init(string: UiTweaks.noPriceMarker) }
                return strongSelf.asValueAttributedString(for: balance) ?? .init(string: UiTweaks.noPriceMarker)
            }

        let viewState = Publishers.CombineLatest(title, value)
            .map { title, value in FungibleTokenHeaderViewModel.ViewState(title: title, value: value) }
            .removeDuplicates()

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    private func runRefreshHeaderTimer() {
        let timer = Timer(timeInterval: headerViewRefreshInterval, repeats: true) { [weak self] _ in
           self?.tiggleIsShowingValue()
        }

        RunLoop.main.add(timer, forMode: .default)
        headerRefreshTimer = timer
    }

    private func invalidateRefreshHeaderTimer() {
        headerRefreshTimer?.invalidate()
        headerRefreshTimer = nil
    }

    private func tiggleIsShowingValue() {
        isShowingValueSubject.value.toggle()
    }

    private var testnetValueHintLabelAttributedString: NSAttributedString {
        return NSAttributedString(string: R.string.localizable.tokenValueTestnetWarning(), attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: R.color.dove()!
        ])
    }

    private func asValueAttributedString(for balance: BalanceViewModel) -> NSAttributedString? {
        if server.isTestnet {
            return testnetValueHintLabelAttributedString
        } else {
            switch transactionType {
            case .nativeCryptocurrency, .erc20Token:
                if isShowingValueSubject.value {
                    return tokenValueAttributedStringFor(balance: balance)
                } else {
                    return marketPriceAttributedStringFor(balance: balance)
                }
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return nil
            }
        }
    }

    private func tokenValueAttributedStringFor(balance: BalanceViewModel) -> NSAttributedString? {
        let string: String = {
            if let currencyAmount = balance.currencyAmount {
                return R.string.localizable.aWalletTokenValue(currencyAmount)
            } else {
                return UiTweaks.noPriceMarker
            }
        }()
        return NSAttributedString(string: string, attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: R.color.dove()!
        ])
    }

    private func marketPriceAttributedStringFor(balance: BalanceViewModel) -> NSAttributedString? {
        guard let marketPrice = marketPriceValueFor(balance: balance), let valuePercentageChange = valuePercentageChangeValueFor(balance: balance) else {
            return nil
        }

        let string = R.string.localizable.aWalletTokenMarketPrice(marketPrice, valuePercentageChange)

        guard let valuePercentageChangeRange = string.range(of: valuePercentageChange) else { return nil }

        let mutableAttributedString = NSMutableAttributedString(string: string, attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: R.color.dove()!
        ])

        let range = NSRange(valuePercentageChangeRange, in: string)
        mutableAttributedString.setAttributes([
            .font: Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 14 : 17),
            .foregroundColor: Screen.TokenCard.Color.valueChangeValue(ticker: balance.ticker)
        ], range: range)

        return mutableAttributedString
    }

    private func valuePercentageChangeValueFor(balance: BalanceViewModel) -> String? {
        switch EthCurrencyHelper(ticker: balance.ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .depreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .none:
            return nil
        }
    }

    private func marketPriceValueFor(balance: BalanceViewModel) -> String? {
        if let value = EthCurrencyHelper(ticker: balance.ticker).marketPrice {
            return Formatter.usd.string(from: value)
        } else {
            return nil
        }
    }

    private func asTitleAttributedString(_ title: String) -> NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Colors.black
        ])
    }

}

extension FungibleTokenHeaderViewModel {
    struct ViewState {
        let title: NSAttributedString
        let value: NSAttributedString
    }
}

extension FungibleTokenHeaderViewModel.ViewState: Equatable { }
