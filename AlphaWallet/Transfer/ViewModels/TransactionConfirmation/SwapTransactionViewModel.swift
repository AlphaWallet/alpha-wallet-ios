//
//  SwapTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation
import Combine

extension TransactionConfirmationViewModel {
    class SwapTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let fromToken: TokenToSwap
        private let fromAmount: BigUInt
        private let toToken: TokenToSwap
        private let toAmount: BigUInt
        private let session: WalletSession
        private let tokensService: TokensProcessingPipeline
        private var cancellable = Set<AnyCancellable>()
        private var sections: [Section] { [.network, .gas, .from, .to] }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator,
             fromToken: TokenToSwap,
             fromAmount: BigUInt,
             toToken: TokenToSwap,
             toAmount: BigUInt,
             tokensService: TokensProcessingPipeline) {
            
            self.configurator = configurator
            self.fromToken = fromToken
            self.fromAmount = fromAmount
            self.toToken = toToken
            self.toAmount = toAmount
            self.session = configurator.session
            self.tokensService = tokensService
            self.confirmButtonViewModel = ConfirmButtonViewModel(
                configurator: configurator,
                title: R.string.localizable.confirmPaymentConfirmButtonTitle())
        }

        func transform(input: TransactionConfirmationViewModelInput) -> TransactionConfirmationViewModelOutput {
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
            tokensService.tokenViewModelPublisher(for: etherToken)
                .map { $0?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
                .map { $0.flatMap { Loadable<CurrencyRate, Error>.done($0) } ?? .failure(SendFungiblesTransactionViewModel.NoCurrencyRateError()) }
                .assign(to: \.etherCurrencyRate, on: self, ownership: .weak)
                .store(in: &cancellable)

            let viewState = Publishers.Merge($etherCurrencyRate.mapToVoid(), configurator.objectChanges)
                .map { _ in
                    TransactionConfirmationViewModel.ViewState(
                        title: R.string.localizable.tokenTransactionConfirmationTitle(),
                        views: self.buildTypedViews(),
                        isSeparatorHidden: true)
                }

            return TransactionConfirmationViewModelOutput(viewState: viewState.eraseToAnyPublisher())
        }

        func shouldShowChildren(for section: Int, index: Int) -> Bool {
            return true
        }

        private func buildTypedViews() -> [ViewType] {
            var views: [ViewType] = []
            for (sectionIndex, section) in sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: session.server.canUserChangeGas)]
                case .network, .from, .to:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
            return views
        }

        private func buildHeaderViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: !sections[section].isExpandable)

            let headerName = sections[section].title

            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: etherCurrencyRate.value)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, details: gasFee, viewState: viewState)
                }
            case .from:
                let doubleAmount = (Decimal(bigInt: BigInt(fromAmount), decimals: fromToken.decimals) ?? .zero).doubleValue
                let amount = NumberFormatter.shortCrypto.string(double: doubleAmount, minimumFractionDigits: 4, maximumFractionDigits: 8)

                return .init(title: .normal("\(amount) \(fromToken.symbol)"), headerName: headerName, viewState: viewState)
            case .to:
                let doubleAmount = (Decimal(bigInt: BigInt(toAmount), decimals: toToken.decimals) ?? .zero).doubleValue
                let amount = NumberFormatter.shortCrypto.string(double: doubleAmount, minimumFractionDigits: 4, maximumFractionDigits: 8)

                return .init(title: .normal("\(amount) \(toToken.symbol)"), headerName: headerName, viewState: viewState)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            }
        }
    }
}

extension TransactionConfirmationViewModel.SwapTransactionViewModel {
    enum Section {
        case gas
        case network
        case from
        case to

        var title: String {
            switch self {
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .network:
                return R.string.localizable.tokenTransactionConfirmationNetwork()
            case .from:
                return R.string.localizable.transactionFromLabelTitle()
            case .to:
                return R.string.localizable.transactionToLabelTitle()
            }
        }

        var isExpandable: Bool {
            return false
        }
    }
}
