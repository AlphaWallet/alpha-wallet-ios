//
//  CancelTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation
import Combine

struct CurrencyRate {
    let currency: Currency
    let value: Double
}

extension TransactionConfirmationViewModel {
    class CancelTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let session: WalletSession
        private var cancellable = Set<AnyCancellable>()
        private let tokensService: TokensProcessingPipeline
        private var sections: [Section] { [.gas, .network, .description] }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator, tokensService: TokensProcessingPipeline) {
            self.configurator = configurator
            self.tokensService = tokensService
            self.session = configurator.session
            self.confirmButtonViewModel = ConfirmButtonViewModel(
                configurator: configurator,
                title: R.string.localizable.tokenTransactionCancelConfirmationTitle())
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
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, viewState: viewState)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            }
        }
    }
}

extension TransactionConfirmationViewModel.CancelTransactionViewModel {
    enum Section {
        case gas
        case network
        case description

        var title: String {
            switch self {
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .description:
                return R.string.localizable.activityCancelDescription()
            case .network:
                return R.string.localizable.tokenTransactionConfirmationNetwork()
            }
        }

        var isExpandable: Bool { return false }
    }
}

extension GasSpeed {
    public var title: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverage()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlow()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFast()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapid()
        case .custom:
            return R.string.localizable.transactionConfigurationTypeCustom()
        }
    }

    public var estimatedProcessingTime: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverageTime()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlowTime()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFastTime()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapidTime()
        case .custom:
            return ""
        }
    }
}

extension TransactionConfigurator.GasPriceWarning: LocalizedWarning {
    public var shortTitle: String {
        switch warning {
        case .tooHighCustomGasPrice, .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceTooHighShort()
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowShort()
        }
    }

    var longTitle: String {
        switch warning {
        case .tooHighCustomGasPrice, .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceTooHighLong()
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowLong()
        }
    }

    public var warningDescription: String? {
        switch warning {
        case .tooHighCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooHighDescription()
        case .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceCongestedDescription(server.blockChainName)
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowDescription()
        }
    }
}

extension TransactionConfigurator.GasLimitWarning {
    var description: String {
        ConfigureTransactionError.gasLimitTooHigh.localizedDescription
    }
}

extension TransactionConfigurator.GasFeeWarning {
    var description: String {
        ConfigureTransactionError.gasFeeTooHigh.localizedDescription
    }
}

extension ConfigureTransactionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .gasLimitTooHigh:
            return R.string.localizable.configureTransactionErrorGasLimitTooHigh(ConfigureTransaction.gasLimitMax)
        case .gasFeeTooHigh:
            return R.string.localizable.configureTransactionErrorGasFeeTooHigh(EtherNumberFormatter.short.string(from: BigInt(ConfigureTransaction.gasFeeMax)))
        case .nonceNotPositiveNumber:
            return R.string.localizable.configureTransactionErrorNonceNotPositiveNumber()
        case .gasPriceTooLow:
            return R.string.localizable.configureTransactionErrorGasPriceTooLow()
        case .leaveNonceEmpty:
            return R.string.localizable.configureTransactionErrorLeaveNonceEmpty()
        }
    }
}

extension AddCustomChainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            //This is the default behavior, just keep it
            return "\(self)"
        case .missingBlockchainExplorerUrl:
            return R.string.localizable.addCustomChainErrorNoBlockchainExplorerUrl()
        case .invalidBlockchainExplorerUrl:
            return R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl()
        case .noRpcNodeUrl:
            return R.string.localizable.addCustomChainErrorNoRpcNodeUrl()
        case .invalidChainId(let chainId):
            return R.string.localizable.addCustomChainErrorInvalidChainId(chainId)
        case .chainIdNotMatch(let result, let chainId):
            return R.string.localizable.addCustomChainErrorChainIdNotMatch(result, chainId)
        case .unknown(let error):
            return "\(R.string.localizable.addCustomChainErrorUnknown()) — \(error)"
        }
    }
}
