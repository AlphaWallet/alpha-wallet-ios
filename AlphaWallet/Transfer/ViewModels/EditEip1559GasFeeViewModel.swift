//
//  EditEip1559GasFeeViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Combine
import AlphaWalletFoundation
import BigInt

struct EditEip1559GasFeeViewModelInput {

}

struct EditEip1559GasFeeViewModelOuput {
    let maxFeeHeader: AnyPublisher<String, Never>
    let maxPriorityFeeHeader: AnyPublisher<String, Never>
}

class EditEip1559GasFeeViewModel: EditGasPriceViewModel {
    private let gasPriceEstimator: Eip1559GasPriceEstimator
    private var cancellable = Set<AnyCancellable>()

    @Published private var maxFeePerGas: FillableValue<BigUInt> = FillableValue<BigUInt>(value: BigUInt(), warnings: [], errors: [])
    @Published private var maxPriorityFeePerGas: FillableValue<BigUInt> = FillableValue<BigUInt>(value: BigUInt(), warnings: [], errors: [])

    var gasPrice: FillableValue<GasPrice> {
        FillableValue<GasPrice>(
            value: GasPrice.eip1559(maxFeePerGas: maxFeePerGas.value, maxPriorityFeePerGas: maxPriorityFeePerGas.value),
            warnings: maxFeePerGas.warnings + maxPriorityFeePerGas.warnings,
            errors: maxFeePerGas.errors + maxPriorityFeePerGas.errors)
    }

    var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> {
        Publishers.CombineLatest($maxFeePerGas, $maxPriorityFeePerGas)
            .map { value in
                return FillableValue<GasPrice>(
                    value: GasPrice.eip1559(maxFeePerGas: value.0.value, maxPriorityFeePerGas: value.1.value),
                    warnings: value.0.warnings + value.1.warnings,
                    errors: value.0.errors + value.1.errors)
            }.eraseToAnyPublisher()
    }

    lazy var maxFeeSliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(value: 0, minimumValue: 0, maximumValue: 10)
    }()

    lazy var maxPriorityFeeSliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(value: 0, minimumValue: 0, maximumValue: 4)
    }()

    init(gasPriceEstimator: Eip1559GasPriceEstimator, server: RPCServer) {
        self.gasPriceEstimator = gasPriceEstimator
    }

    func save() {
        guard maxFeePerGas.errors.isEmpty && maxPriorityFeePerGas.errors.isEmpty else { return }

        gasPriceEstimator.set(
            maxFeePerGas: maxFeePerGas.value,
            maxPriorityFeePerGas: maxPriorityFeePerGas.value)
    }

    func trasform(input: EditEip1559GasFeeViewModelInput) -> EditEip1559GasFeeViewModelOuput {

        let gasPriceEstimator = gasPriceEstimator

        let maxFeePerGas = maxFeeSliderViewModel.$value
            .map { Decimal($0).toBigUInt(units: UnitConfiguration.gasPriceUnit) ?? BigUInt() }
            .map { [gasPriceEstimator] in gasPriceEstimator.validate(maxFeePerGas: $0) }

        let maxPriorityFeePerGas = maxPriorityFeeSliderViewModel.$value
            .map { Decimal($0).toBigUInt(units: UnitConfiguration.gasPriceUnit) ?? BigUInt() }
            .map { [gasPriceEstimator] in gasPriceEstimator.validate(maxPriorityFee: $0) }

        maxFeePerGas.assign(to: \.maxFeePerGas, on: self, ownership: .weak)
            .store(in: &cancellable)

        maxPriorityFeePerGas.assign(to: \.maxPriorityFeePerGas, on: self, ownership: .weak)
            .store(in: &cancellable)

        maxFeePerGas.compactMap { [weak self] in self?.buildErrorState($0) }
            .assign(to: \.status, on: maxFeeSliderViewModel, ownership: .weak)
            .store(in: &cancellable)

        maxPriorityFeePerGas.compactMap { [weak self] in self?.buildErrorState($0) }
            .assign(to: \.status, on: maxPriorityFeeSliderViewModel, ownership: .weak)
            .store(in: &cancellable)

        gasPriceEstimator.estimatesPublisher
            .map { _ in gasPriceEstimator.availableMaxFeeRange }
            .sink { [weak maxFeeSliderViewModel] in maxFeeSliderViewModel?.set(range: $0) }
            .store(in: &cancellable)

        gasPriceEstimator.oraclePublisher
            .map { Decimal(bigUInt: $0.value.maxFeePerGas, units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue }
            .sink { [weak maxFeeSliderViewModel] in maxFeeSliderViewModel?.set(value: $0) }
            .store(in: &cancellable)

        gasPriceEstimator.oraclePublisher
            .map { Decimal(bigUInt: $0.value.maxPriorityFeePerGas, units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue }
            .sink { [weak maxPriorityFeeSliderViewModel] in maxPriorityFeeSliderViewModel?.set(value: $0) }
            .store(in: &cancellable)

        return .init(
            maxFeeHeader: Just(R.string.localizable.configureTransactionHeaderMaxFee()).eraseToAnyPublisher(),
            maxPriorityFeeHeader: Just(R.string.localizable.configureTransactionHeaderMaxPriorityFee()).eraseToAnyPublisher())
    }

    private func buildErrorState(_ fillableValue: FillableValue<BigUInt>) -> TextField.TextFieldErrorState {
        if let error = fillableValue.errors.first {
            return .error(error.localizedDescription)
        }
        if let warning = fillableValue.warnings.first {
            return .error(warning.localizedDescription)
        }
        return .none
    }
}

extension Eip1559GasPriceEstimator.MaxGasFeeWarning: LocalizedWarning {
    public var warningDescription: String? {
        switch self {
        case .tooHigh: return R.string.localizable.eip1559WarningMaxFeeTooHigh()
        case .tooLow: return R.string.localizable.eip1559WarningMaxFeeTooLow()
        }
    }
}

extension Eip1559GasPriceEstimator.PriorityFeeWarning: LocalizedWarning {
    public var warningDescription: String? {
        switch self {
        case .tooHigh: return R.string.localizable.eip1559WarningPriorityFeeTooHigh()
        case .tooLow: return R.string.localizable.eip1559WarningPriorityFeeTooLow()
        }
    }
}

extension Eip1559GasPriceEstimator.MaxGasFeeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .zeroMaxFee: return R.string.localizable.eip1559ErrorZeroMaxFee()
        case .invalid: return R.string.localizable.eip1559ErrorInvalidMaxFee()
        }
    }
}

extension Eip1559GasPriceEstimator.PriorityFeeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .zeroPriorityFee: return R.string.localizable.eip1559ErrorZeroPriorityFee()
        case .invalid: return R.string.localizable.eip1559ErrorInvalidMaxFee()
        }
    }
}
