//
//  SelectAssetViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.02.2023.
//

import UIKit
import Combine

struct SelectAssetViewModelInput {
    let increase: AnyPublisher<Void, Never>
    let decrease: AnyPublisher<Void, Never>
}

struct SelectAssetViewModelOutput {
    let text: AnyPublisher<String, Never>
}

class SelectAssetViewModel {
    private let available: Int
    private var cancellable = Set<AnyCancellable>()
    private let selectedSubject: CurrentValueSubject<Int, Never>

    var selected: AnyPublisher<Int, Never> {
        selectedSubject.eraseToAnyPublisher()
    }

    init(available: Int = 0, selected: Int = 0) {
        self.available = available
        self.selectedSubject = .init(selected)
    }

    func transform(input: SelectAssetViewModelInput) -> SelectAssetViewModelOutput {
        input.increase
            .flatMap { [selectedSubject] _ in selectedSubject.first() }
            .filter { [available] in $0 + 1 <= available }
            .map { $0 + 1 }
            .assign(to: \.value, on: selectedSubject)
            .store(in: &cancellable)

        input.decrease
            .flatMap { [selectedSubject] _ in selectedSubject.first() }
            .filter { $0 - 1 >= 0 }
            .map { $0 - 1 }
            .assign(to: \.value, on: selectedSubject)
            .store(in: &cancellable)

        let text = selectedSubject.map { $0.description }

        return .init(text: text.eraseToAnyPublisher())
    }

    func set(counter: String) {
        if counter.isEmpty {
            selectedSubject.value = 0
        } else {
            guard let value = Int(counter), value >= 0 && value <= available else { return }
            selectedSubject.value = value
        }
    }
}
