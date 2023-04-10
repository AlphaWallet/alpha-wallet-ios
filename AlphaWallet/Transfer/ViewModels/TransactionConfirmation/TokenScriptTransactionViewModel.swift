//
//  TokenScriptTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import BigInt
import AlphaWalletFoundation
import Combine

extension TransactionConfirmationViewModel {
    class TokenScriptTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let tokensService: TokensProcessingPipeline
        private let address: AlphaWallet.Address
        private let configurator: TransactionConfigurator
        private let session: WalletSession
        private var cancellable = Set<AnyCancellable>()
        private let functionCallMetaData: DecodedFunctionCall
        private var sections: [Section] { Section.allCases }

        var openedSections = Set<Int>()
        let confirmButtonViewModel: ConfirmButtonViewModel

        init(address: AlphaWallet.Address,
             configurator: TransactionConfigurator,
             functionCallMetaData: DecodedFunctionCall,
             tokensService: TokensProcessingPipeline) {

            self.tokensService = tokensService
            self.address = address
            self.configurator = configurator
            self.functionCallMetaData = functionCallMetaData
            self.session = configurator.session
            self.confirmButtonViewModel = ConfirmButtonViewModel(
                configurator: configurator,
                title: R.string.localizable.confirmPaymentConfirmButtonTitle())
        }

        func shouldShowChildren(for section: Int, index: Int) -> Bool {
            return true
        }

        func transform(input: TransactionConfirmationViewModelInput) -> TransactionConfirmationViewModelOutput {
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)
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
                        isSeparatorHidden: false)
                }

            return TransactionConfirmationViewModelOutput(
                viewState: viewState.eraseToAnyPublisher())
        }

        private var formattedAmountValue: String {
            //FIXME: is here ether token?
            let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: session.server.decimals) ?? .zero).doubleValue
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if let rate = etherCurrencyRate.value {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"

                return "\(amount) \(session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(session.server.symbol)"
            }
        }

        private func buildTypedViews() -> [ViewType] {
            var views: [ViewType] = []
            for (sectionIndex, section) in sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: session.server.canUserChangeGas)]
                case .function:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]

                    let isSubViewsHidden = isSubviewsHidden(section: sectionIndex)
                    let vm = TransactionConfirmationRowInfoViewModel(title: "\(functionCallMetaData.name)()", subtitle: "")

                    views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]

                    for arg in functionCallMetaData.arguments {
                        let vm = TransactionConfirmationRowInfoViewModel(title: arg.type.description, subtitle: arg.description)
                        views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    }
                case .contract, .amount, .network:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
            return views
        }

        private func buildHeaderViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: sections[section] != .function)

            let headerName = sections[section].title

            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: etherCurrencyRate.value)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, details: gasFee, viewState: viewState)
                }
            case .contract:
                return .init(title: .normal(address.truncateMiddle), headerName: headerName, viewState: viewState)
            case .function:
                return .init(title: .normal(functionCallMetaData.name), headerName: headerName, viewState: viewState)
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, viewState: viewState)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            }
        }

        func isSubviewsHidden(section: Int) -> Bool {
            !openedSections.contains(section)
        }
    }
}

extension TransactionConfirmationViewModel.TokenScriptTransactionViewModel {
    enum Section: Int, CaseIterable {
        case gas
        case network
        case contract
        case function
        case amount

        var title: String {
            switch self {
            case .network:
                return R.string.localizable.tokenTransactionConfirmationNetwork()
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .contract:
                return R.string.localizable.tokenTransactionConfirmationContractTitle()
            case .function:
                return R.string.localizable.tokenTransactionConfirmationFunctionTitle()
            case .amount:
                return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
            }
        }
    }
}
