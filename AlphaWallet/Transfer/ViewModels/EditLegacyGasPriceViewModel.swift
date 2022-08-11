//
//  EditLegacyGasPriceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Combine
import AlphaWalletFoundation
import BigInt

protocol EditGasPriceViewModel {
    var gasPrice: FillableValue<GasPrice> { get }
    var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> { get }

    func save()
}

struct EditLegacyGasPriceViewModelInput {

}

struct EditLegacyGasPriceViewModelOuput {
    let title: AnyPublisher<String, Never>
}

class EditLegacyGasPriceViewModel: EditGasPriceViewModel {
    private let gasPriceEstimator: LegacyGasPriceEstimator
    private var cancellable = Set<AnyCancellable>()
    private let server: RPCServer
    @Published private var _gasPrice: FillableValue<BigUInt> = FillableValue<BigUInt>(value: BigUInt(), warnings: [], errors: [])

    var gasPrice: FillableValue<GasPrice> {
        _gasPrice.mapValue { GasPrice.legacy(gasPrice: $0) }
    }
    var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> {
        $_gasPrice.map { $0.mapValue { GasPrice.legacy(gasPrice: $0) } }.eraseToAnyPublisher()
    }

    lazy var sliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(
            value: Decimal(bigUInt: gasPriceEstimator.gasPrice.value.max, units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue,
            minimumValue: Decimal(bigUInt: GasPriceConfiguration.minPrice, units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue,
            maximumValue: Decimal(bigUInt: GasPriceConfiguration.maxPrice(forServer: server), units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue)
    }()

    init(gasPriceEstimator: LegacyGasPriceEstimator, server: RPCServer) {
        self.gasPriceEstimator = gasPriceEstimator
        self.server = server
    }

    func save() {
        guard _gasPrice.errors.isEmpty else { return }
        gasPriceEstimator.set(gasCustomPrice: _gasPrice.value)
    }

    func trasform(input: EditLegacyGasPriceViewModelInput) -> EditLegacyGasPriceViewModelOuput {
        let gasPriceEstimator = gasPriceEstimator

        let gasPrice = sliderViewModel.$value
            .map { Decimal($0).toBigUInt(units: UnitConfiguration.gasPriceUnit) ?? BigUInt() }
            .map { [gasPriceEstimator] in gasPriceEstimator.validate(gasPrice: $0) }

        gasPrice.assign(to: \._gasPrice, on: self, ownership: .weak)
            .store(in: &cancellable)

        gasPrice.compactMap { [weak self] in self?.buildTextFieldState($0) }
            .assign(to: \.status, on: sliderViewModel, ownership: .weak)
            .store(in: &cancellable)

        gasPriceEstimator.gasPricePublisher
            .map { Decimal(bigUInt: $0.value.max, units: UnitConfiguration.gasPriceUnit, fallback: .zero).doubleValue }
            .sink { [weak sliderViewModel] in sliderViewModel?.set(value: $0) }
            .store(in: &cancellable)

        return .init(title: Just(R.string.localizable.configureTransactionHeaderGasPrice()).eraseToAnyPublisher())
    }

    private func buildTextFieldState(_ value: FillableValue<BigUInt>) -> TextField.TextFieldErrorState {
        if let error = value.errors.first {
            return .error(error.localizedDescription)
        }

        if let _ = value.warnings.first {
            return .error("")
        }
        return .none
    }
}
