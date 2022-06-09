//
//  SlippageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

class SlippageView: UIView {

    private lazy var cancelable = Set<AnyCancellable>()

    private enum SlippageInputType {
        case selectableView(SelectableSlippageView, each: SwapSlippage)
        case editableView(EditableSlippageView)

        var view: UIView {
            switch self {
            case .selectableView(let v, _): return v
            case .editableView(let v): return v
            }
        }
    }

    private lazy var slippageValueViews: [SlippageView.SlippageInputType] = viewModel
        .initialSlippageValues
        .map { each -> SlippageInputType in
            switch each.viewType {
            case .selectionButton:
                let view = SelectableSlippageView()
                view.widthAnchor.constraint(equalToConstant: 60).isActive = true

                return .selectableView(view, each: each)
            case .editingTextField:
                let view = EditableSlippageView(viewModel: EditableSlippageViewModel(selectedSlippage: viewModel.selectedSlippage))

                return .editableView(view)
            }
        }

    private let viewModel: SlippageViewModel

    init(viewModel: SlippageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = (slippageValueViews.map { $0.view } + [.spacerWidth(flexible: true)])
            .asStackView(axis: .horizontal, spacing: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            heightAnchor.constraint(equalToConstant: 40)
        ])

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SlippageViewModel) {
        viewModel
            .availableSlippages
            .receive(on: RunLoop.main)
            .sink { viewModels in
                for index in viewModels.indices {
                    switch self.slippageValueViews[index] {
                    case .selectableView(let button, _):
                        let viewModel = viewModels[index]
                        button.configure(viewModel: viewModel)
                    case _: break//no-op
                    }
                }
            }.store(in: &cancelable)

        for each in slippageValueViews {
            switch each {
            case .selectableView(let view, let value):
                view.actionButton.publisher(forEvent: .touchUpInside)
                    .map { _ -> SwapSlippage in return value }
                    .eraseToAnyPublisher()
                    .receive(on: RunLoop.main)
                    .sink(receiveValue: { value in
                        viewModel.set(slippage: value)
                    })
                    .store(in: &cancelable)
            case .editableView: break
            }
        }
    }
}
