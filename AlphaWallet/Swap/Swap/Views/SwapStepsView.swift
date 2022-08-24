//
//  SwapStepsView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

final class SwapStepsView: UIView {
    private var viewModel: SwapStepsViewModel

    private var swapLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.backgroundColor = UIColor.init(red: 74, green: 74, blue: 74)

        return view
    }()
    private var stackView: UIStackView = [UIView]([]).asStackView(axis: .vertical)
    private var cancelable = Set<AnyCancellable>()

    init(viewModel: SwapStepsViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let bottomLine: UIView = .spacer(height: 1, backgroundColor: R.color.mercury()!)
        let edgeInsets = UIEdgeInsets(top: 15, left: 25, bottom: 15, right: 25)
        stackView.translatesAutoresizingMaskIntoConstraints =  false

        addSubview(stackView)
        addSubview(swapLine)
        addSubview(bottomLine)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: SwapStepsViewModel) {
        viewModel.swapStepsViewModels
        .map { $0.map { viewModel in SwapStepView(viewModel: viewModel) } }
        .sink { [stackView] views in
            stackView.removeAllArrangedSubviews()
            stackView.addArrangedSubviews(views)

            NSLayoutConstraint.activate(self.buildContraints(for: views))
        }.store(in: &cancelable)
    }

    private func buildContraints(for views: [UIView]) -> [NSLayoutConstraint] {
        if views.isEmpty {
            return []
        } else {
            return [
                swapLine.topAnchor.constraint(equalTo: views[0].centerYAnchor),
                swapLine.bottomAnchor.constraint(equalTo: views[views.count - 1].centerYAnchor),
                swapLine.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 4.5)
            ]
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
