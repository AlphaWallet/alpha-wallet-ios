//
//  SlidableTextFieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import Foundation
import Combine

struct SlidableTextFieldViewModelInput {
    let sliderChanged: AnyPublisher<Float, Never>
    let textChanged: AnyPublisher<Float, Never>
}

struct SlidableTextFieldViewModelOutput {
    let sliderViewState: AnyPublisher<SlidableTextFieldViewModel.SliderViewState, Never>
    let text: AnyPublisher<String, Never>
    let status: AnyPublisher<TextField.TextFieldErrorState, Never>
}

class SlidableTextFieldViewModel {
    @Published private var valueState: ValueState<Float>
    private let defaultMinimumValue: Float
    private let defaultMaximumValue: Float
    private var overriddenMaxValue: Float?
    private var maximumValue: Float { overriddenMaxValue ?? defaultMaximumValue }
    private let setValueSubject = PassthroughSubject<Float, Never>()
    private var cancellable = Set<AnyCancellable>()
    
    @Published private (set) var value: Float
    @Published var status: TextField.TextFieldErrorState = .none

    init(value: Float,
         minimumValue: Float,
         maximumValue: Float) {

        self.value = value
        self.valueState = .initial(value)
        self.defaultMinimumValue = minimumValue
        self.defaultMaximumValue = maximumValue
        
        adjustUpperBound(value)
    }

    func set(value: Float, changeBehaviour: ChangeBehaviour = .updateWhileInitial) {
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
            .map { ValueState<Float>.changed($0) }
            .assign(to: \.valueState, on: self, ownership: .weak)
            .store(in: &cancellable)

        $valueState
            .map { $0.value }
            .assign(to: \.value, on: self, ownership: .weak)
            .store(in: &cancellable)

        input.sliderChanged
            .map { ValueState<Float>.changed($0) }
            .assign(to: \.valueState, on: self, ownership: .weak)
            .store(in: &cancellable)

        let sliderViewState = Publishers.Merge(setValueSubject.prepend(valueState.value), textChanged)
            .map { SliderViewState(value: $0, range: self.defaultMinimumValue ... self.maximumValue) }
            .removeDuplicates()

        let text = Publishers.Merge(setValueSubject.prepend(valueState.value), input.sliderChanged)
            .map { String($0).droppedTrailingZeros }
            .removeDuplicates()

        return .init(
            sliderViewState: sliderViewState.eraseToAnyPublisher(),
            text: text.eraseToAnyPublisher(),
            status: $status.eraseToAnyPublisher())
    }

    private func adjustUpperBound(_ value: Float) {
        if value > defaultMaximumValue {
            overriddenMaxValue = value
        } else if value < defaultMinimumValue {
            overriddenMaxValue = nil
        }
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
