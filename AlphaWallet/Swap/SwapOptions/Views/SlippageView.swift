//
//  SlippageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

class SlippageView: UIView {

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
    private lazy var cancelable = Set<AnyCancellable>()
    private let viewModel: SlippageViewModel
    private var slippageViews: [SlippageInputType] = []
    private let stackView: UIStackView = [UIView]().asStackView(axis: .horizontal, spacing: 8)

    init(viewModel: SlippageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self)
        ])

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SlippageViewModel) {
        let input = SlippageViewModelInput()
        let output = viewModel.transform(input: input)

        output.availableSlippages
            .sink { [weak self] viewModels in
                for index in viewModels.indices {
                    switch self?.slippageViews[index] {
                    case .selectableView(let button, _):
                        let viewModel = viewModels[index]
                        button.configure(viewModel: viewModel)
                    case _: break//no-op
                    }
                }
            }.store(in: &cancelable)

        let views = output.views.map { [self] views -> [SlippageInputType] in
            views.map { each in self.buildView(for: each) }
        }.handleEvents(receiveOutput: { [weak self] in self?.slippageViews = $0 })

        views.sink { [stackView] viewTypes in
            let views = viewTypes.map { $0.view } + [.spacerWidth(flexible: true)]

            stackView.removeAllArrangedSubviews()
            stackView.addArrangedSubviews(views)
        }.store(in: &cancelable)
    }

    private func buildView(for each: SwapSlippage) -> SlippageInputType {
        switch each.viewType {
        case .selectionButton:
            let view = SelectableSlippageView()
            view.widthAnchor.constraint(equalToConstant: 60).isActive = true
            view.actionButton.publisher(forEvent: .touchUpInside)
                .map { _ -> SwapSlippage in return each }
                .sink(receiveValue: { [weak viewModel] value in
                    viewModel?.set(slippage: value)
                }).store(in: &cancelable)

            return .selectableView(view, each: each)
        case .editingTextField:
            let view = EditableSlippageView(viewModel: EditableSlippageViewModel(selectedSlippage: viewModel.selectedSlippage))

            return .editableView(view)
        }
    }
}
