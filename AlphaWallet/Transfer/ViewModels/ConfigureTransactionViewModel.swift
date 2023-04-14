// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletFoundation
import Combine
import AlphaWalletCore

struct ConfigureTransactionViewModelInput {
    let saveSelected: AnyPublisher<Void, Never>
}

struct ConfigureTransactionViewModelOutput {
    let gasPriceWarning: AnyPublisher<TransactionConfigurator.GasPriceWarning?, Never>
    let viewState: AnyPublisher<ConfigureTransactionViewModel.ViewState, Never>
    let didSave: AnyPublisher<Void, Never>
}

class ConfigureTransactionViewModel {
    private let service: TokensProcessingPipeline
    private let configurator: TransactionConfigurator
    private var cancellable = Set<AnyCancellable>()
    private var server: RPCServer { configurator.session.server }
    private let selectedGasSpeedSubject: CurrentValueSubject<GasSpeed, Never>
    private let gasPriceEstimator: GasPriceEstimator

    let editTransactionViewModel: EditTransactionViewModel
    let allGasSpeeds: [GasSpeed] = [.slow, .standard, .fast, .rapid, .custom]
    let updateInViewModel: UpdateInViewModel

    init(configurator: TransactionConfigurator,
         recoveryMode: EditTransactionViewModel.RecoveryMode,
         service: TokensProcessingPipeline) {

        self.gasPriceEstimator = configurator.gasPriceEstimator
        let gasPriceViewModel: EditGasPriceViewModel
        if let gasPriceEstimator = gasPriceEstimator as? LegacyGasPriceEstimator {
            gasPriceViewModel = EditLegacyGasPriceViewModel(
                gasPriceEstimator: gasPriceEstimator,
                server: configurator.session.server)
        } else if let gasPriceEstimator = gasPriceEstimator as? Eip1559GasPriceEstimator {
            gasPriceViewModel = EditEip1559GasFeeViewModel(
                gasPriceEstimator: gasPriceEstimator,
                server: configurator.session.server)
        } else {
            fatalError()
        }

        editTransactionViewModel = EditTransactionViewModel(
            configurator: configurator,
            recoveryMode: recoveryMode,
            service: service,
            gasPriceViewModel: gasPriceViewModel)

        self.configurator = configurator

        self.service = service
        switch recoveryMode {
        case .invalidNonce:
            selectedGasSpeedSubject = .init(.custom)
        case .none:
            selectedGasSpeedSubject = .init(configurator.selectedGasSpeed)
        }

        updateInViewModel = UpdateInViewModel(gasPriceEstimator: gasPriceEstimator)
    }

    func transform(input: ConfigureTransactionViewModelInput) -> ConfigureTransactionViewModelOutput {
        let gasPriceViewModel = editTransactionViewModel.gasPriceViewModel

        let baseEstimates = Publishers.CombineLatest(gasPriceEstimator.estimatesPublisher, configurator.$gasLimit)
            .map { self.buildGasViewModels(estimates: $0.0, gasLimit: $0.1.value) }

        let customEstimate = Publishers.CombineLatest(gasPriceViewModel.gasPricePublisher, editTransactionViewModel.$gasLimit)
            .map { (gasSpeed: GasSpeed.custom, gasPrice: $0.0.value, gasLimit: $0.1) }

        let estimates = Publishers.CombineLatest3(baseEstimates, customEstimate, selectedGasSpeedSubject)
            .map { baseEstimates, customEstimate, selected -> (estimates: [GasSpeedViewModel], selected: GasSpeed) in
                return (estimates: baseEstimates + [customEstimate], selected: selected)
            }

        let viewState = Publishers.CombineLatest(estimates, etherCurrencyRate())
            .map { estimates, rate in
                let viewModels = estimates.estimates.map { self.buildGasSpeedViewModel(viewModel: $0, selectedSpeed: estimates.selected, rate: rate) }

                return ConfigureTransactionViewModel.ViewState(
                    gasSpeedViewModels: viewModels,
                    isEditTransactionHidden: estimates.selected != .custom)
            }

        let didSave = input.saveSelected
            .filter { _ in self.save() }

        let gasPriceWarning = gasPriceViewModel.gasPricePublisher
            .map { $0.warnings.compactMap { $0 as? TransactionConfigurator.GasPriceWarning }.first }

        return .init(
            gasPriceWarning: gasPriceWarning.eraseToAnyPublisher(),
            viewState: viewState.eraseToAnyPublisher(),
            didSave: didSave.eraseToAnyPublisher())
    }

    private func save() -> Bool {
        switch selectedGasSpeedSubject.value {
        case .custom:
            return editTransactionViewModel.save()
        case .standard, .fast, .rapid, .slow:
            configurator.gasPriceEstimator.set(gasSpeed: selectedGasSpeedSubject.value)
            return true
        }
    }

    func select(gasSpeed: GasSpeed) {
        guard selectedGasSpeedSubject.value != gasSpeed else { return }
        selectedGasSpeedSubject.value = gasSpeed
    }

    private func etherCurrencyRate() -> AnyPublisher<CurrencyRate?, Never> {
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        return service.tokenViewModelPublisher(for: etherToken)
            .map { $0?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
            .eraseToAnyPublisher()
    }

    private func buildGasViewModels(estimates: GasEstimates, gasLimit: BigUInt) -> [GasSpeedViewModel] {
        return allGasSpeeds.map { gasSpeed -> GasSpeedViewModel in
            return (gasSpeed: gasSpeed, gasPrice: estimates[gasSpeed], gasLimit: gasLimit)
        }
    }

    private func buildGasSpeedViewModel(viewModel: GasSpeedViewModel, selectedSpeed: GasSpeed, rate: CurrencyRate?) -> GasSpeedViewModelType {
        let isSelected = selectedSpeed == viewModel.gasSpeed

        guard let gasPrice = viewModel.gasPrice else {
            return UnavailableGasSpeedViewModel(gasSpeed: viewModel.gasSpeed, isSelected: false, isHidden: true)
        }

        switch gasPrice {
        case .legacy(let gasPrice):
            return LegacyGasSpeedViewModel(
                gasPrice: gasPrice,
                gasLimit: viewModel.gasLimit,
                gasSpeed: viewModel.gasSpeed,
                rate: rate,
                symbol: server.symbol,
                isSelected: isSelected,
                isHidden: false)
        case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas):
            return Eip1559GasSpeedViewModel(
                gasSpeed: viewModel.gasSpeed,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                gasLimit: viewModel.gasLimit,
                rate: rate,
                symbol: server.symbol,
                isSelected: isSelected,
                isHidden: false)
        }
    }
}

extension ConfigureTransactionViewModel {
    typealias GasSpeedViewModel = (gasSpeed: GasSpeed, gasPrice: GasPrice?, gasLimit: BigUInt)

    struct ViewState {
        let title: String = R.string.localizable.configureTransactionNavigationBarTitle()
        let gasSpeedViewModels: [GasSpeedViewModelType]
        let isEditTransactionHidden: Bool
    }
}
