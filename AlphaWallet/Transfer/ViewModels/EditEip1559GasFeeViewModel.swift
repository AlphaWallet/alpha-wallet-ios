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

}

class EditEip1559GasFeeViewModel: EditGasPriceViewModel {
    private let estimator: GasPriceEstimator
    private var cancellable = Set<AnyCancellable>()

    @Published private var _maxFeePerGas: BigUInt = BigUInt()
    @Published private var _maxPriorityFeePerGas: BigUInt = BigUInt()
    @Published private var gasPriceWarning: TransactionConfigurator.GasPriceWarning?

    var gasPrice: FillableValue<GasPrice> {
        fatalError()
    }
    var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> {
        fatalError()
    }

    lazy var maxFeeSliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(
            value: 0,
            minimumValue: 1,
            maximumValue: 10)
    }()

    lazy var maxPriorityFeeSliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(
            value: 0,
            minimumValue: 1,
            maximumValue: 10)
    }()

    init(estimator: GasPriceEstimator, server: RPCServer) {
        self.estimator = estimator
    }

    func save() {
        fatalError()
    }

    func trasform(input: EditEip1559GasFeeViewModelInput) -> EditEip1559GasFeeViewModelOuput {
        fatalError()
    }
}
