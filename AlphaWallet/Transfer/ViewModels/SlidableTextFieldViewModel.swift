//
//  SlidableTextFieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import Foundation
import Combine
import AlphaWalletFoundation

struct SlidableTextFieldViewModelInput {
    let sliderChanged: AnyPublisher<Float, Never>
    let textChanged: AnyPublisher<Double, Never>
}

struct SlidableTextFieldViewModelOutput {
    let sliderViewState: AnyPublisher<SlidableTextFieldViewModel.SliderViewState, Never>
    let text: AnyPublisher<String, Never>
    let status: AnyPublisher<TextField.TextFieldErrorState, Never>
}

class SlidableTextFieldViewModel {
    @Published private var valueState: ValueState<Double>
    private var defaultMinimumValue: Double
    private var defaultMaximumValue: Double
    private var overriddenMaxValue: Double?
    private var maximumValue: Double { overriddenMaxValue ?? defaultMaximumValue }
    private let setValueSubject = PassthroughSubject<Double, Never>()
    private var cancellable = Set<AnyCancellable>()
    private let sliderFloatClosedRange = ClosedRange<Double>(uncheckedBounds: (lower: -Double(EthereumUnit.ether.rawValue), upper: Double(EthereumUnit.ether.rawValue)))
    private var closedRange: ClosedRange<Float> {
        ClosedRange<Float>(uncheckedBounds: (lower: Float(defaultMinimumValue), upper: Float(maximumValue)))
    }

    @Published private (set) var value: Double
    @Published var status: TextField.TextFieldErrorState = .none

    init(value: Double,
         minimumValue: Double,
         maximumValue: Double) {

        self.value = value
        self.valueState = .initial(value)
        self.defaultMinimumValue = minimumValue
        self.defaultMaximumValue = maximumValue

        adjustUpperBound(value)
    }

    func set(range: ClosedRange<Double>) {
        defaultMinimumValue = range.lowerBound
        defaultMaximumValue = range.upperBound
        set(value: value, changeBehaviour: .forceUpdate)
    }

    func set(value: Double, changeBehaviour: ChangeBehaviour = .updateWhileInitial) {
        guard allowSetValue(changeBehaviour: changeBehaviour) else { return }
        adjustUpperBound(value)
        setValueSubject.send(value)
        self.value = value
    }

    func transform(input: SlidableTextFieldViewModelInput) -> SlidableTextFieldViewModelOutput {
        let textChanged = input.textChanged
            .handleEvents(receiveOutput: { [weak self] in self?.adjustUpperBound($0) })
            .share()

        textChanged
            .map { ValueState<Double>.changed($0) }
            .assign(to: \.valueState, on: self, ownership: .weak)
            .store(in: &cancellable)

        $valueState
            .map { $0.value }
            .assign(to: \.value, on: self, ownership: .weak)
            .store(in: &cancellable)

        input.sliderChanged
            .map { ValueState<Double>.changed(Double($0)) }
            .assign(to: \.valueState, on: self, ownership: .weak)
            .store(in: &cancellable)

        let sliderViewState = Publishers.Merge(setValueSubject.prepend(valueState.value), textChanged)
            .compactMap { self.safeSliderFloat(double: $0) }
            .map { SliderViewState(value: $0, range: self.closedRange) }
            .removeDuplicates()

        let text = Publishers.Merge(setValueSubject.prepend(valueState.value), input.sliderChanged.map { Double($0) })
            .map { String($0).droppedTrailingZeros }
            .removeDuplicates()

        return .init(
            sliderViewState: sliderViewState.eraseToAnyPublisher(),
            text: text.eraseToAnyPublisher(),
            status: $status.eraseToAnyPublisher())
    }

    private func adjustUpperBound(_ value: Double) {
        if value > defaultMaximumValue {
            overriddenMaxValue = value
        } else if value < defaultMinimumValue {
            overriddenMaxValue = nil
        }
    }

    func convertToDouble(string: String) -> Double? {
        guard let value = DecimalParser().parseAnyDecimal(from: string), sliderFloatClosedRange.contains(value.doubleValue) else { return nil }

        return value.doubleValue
    }

    private func safeSliderFloat(double: Double) -> Float? {
        guard sliderFloatClosedRange.contains(double) else { return nil }
        let float = Float(double)
        guard !float.isNaN && !float.isInfinite else { return nil }

        return float
    }

    private func allowSetValue(changeBehaviour: ChangeBehaviour) -> Bool {
        switch changeBehaviour {
        case .updateWhileInitial:
            guard case .initial = self.valueState else { return false }
            return true
        case .forceUpdate:
            return true
        }
    }
}

extension SlidableTextFieldViewModel {
    struct SliderViewState: Equatable {
        let value: Float
        let range: ClosedRange<Float>
    }

    enum ChangeBehaviour {
        case updateWhileInitial
        case forceUpdate
    }

    enum ValueState<T> {
        case initial(T)
        case changed(T)

        var value: T {
            switch self {
            case .initial(let value): return value
            case .changed(let value): return value
            }
        }
    }
}
