//
//  ClaimPaidErc875MagicLinkViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation
import Combine

extension TransactionConfirmationViewModel {
    class ClaimPaidErc875MagicLinkViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let price: BigUInt
        private let numberOfTokens: UInt
        private let session: WalletSession
        private var cancellable = Set<AnyCancellable>()
        private let tokensService: TokensProcessingPipeline
        private var sections: [Section] { Section.allCases }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator,
             price: BigUInt,
             numberOfTokens: UInt,
             tokensService: TokensProcessingPipeline) {

            self.configurator = configurator
            self.price = price
            self.numberOfTokens = numberOfTokens
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
                        title: R.string.localizable.tokenTransactionPurchaseConfirmationTitle(),
                        views: self.buildTypedViews(),
                        isSeparatorHidden: false)
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
                case .amount, .numberOfTokens, .network:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
            return views
        }

        private func buildHeaderViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: true)

            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            case .gas:
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, viewState: viewState)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, viewState: viewState)
            case .numberOfTokens:
                return .init(title: .normal(String(numberOfTokens)), headerName: headerName, viewState: viewState)
            }
        }

        private var formattedAmountValue: String {
            //NOTE: what actual token can be here? or its always native crypto, need to figure out right `decimals` value, better to pass here actual NSDecimalNumber value
            let amountToSend = (Decimal(bigUInt: price, decimals: session.server.decimals) ?? .zero).doubleValue
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if let rate = etherCurrencyRate.value {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"

                return "\(amount) \(session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(session.server.symbol)"
            }
        }
    }
}

extension TransactionConfirmationViewModel.ClaimPaidErc875MagicLinkViewModel {
    enum Section: Int, CaseIterable {
        case gas
        case network
        case amount
        case numberOfTokens

        var title: String {
            switch self {
            case .network:
                return R.string.localizable.tokenTransactionConfirmationNetwork()
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .amount:
                return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
            case .numberOfTokens:
                return R.string.localizable.tokensTitlecase()
            }
        }
    }
}
