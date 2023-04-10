//
//  SpeedupTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation
import Combine

extension TransactionConfirmationViewModel {
    class SpeedupTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let session: WalletSession
        private let tokensService: TokensProcessingPipeline
        private var cancellable = Set<AnyCancellable>()
        private var sections: [Section] { [.gas, .network, .description] }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator, tokensService: TokensProcessingPipeline) {
            self.configurator = configurator
            self.tokensService = tokensService
            self.session = configurator.session
            self.confirmButtonViewModel = ConfirmButtonViewModel(
                configurator: configurator,
                title: R.string.localizable.activitySpeedup())
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
                        title: R.string.localizable.tokenTransactionSpeedupConfirmationTitle(),
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
                case .description:
                    let vm = TransactionRowDescriptionTableViewCellViewModel(title: section.title)
                    views += [.details(viewModel: vm)]
                case .network:
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
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, viewState: viewState)
            }
        }
    }
}

extension TransactionConfirmationViewModel.SpeedupTransactionViewModel {
    enum Section {
        case gas
        case network
        case description

        var title: String {
            switch self {
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .description:
                return R.string.localizable.activitySpeedupDescription()
            case .network:
                return R.string.localizable.tokenTransactionConfirmationNetwork()
            }
        }

        var isExpandable: Bool { return false }
    }
}
