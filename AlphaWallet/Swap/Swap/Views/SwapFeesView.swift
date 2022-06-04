//
//  SwapFeesView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

final class SwapFeesView: UIView {
    private var viewModel: SwapFeesViewModel
    private var views: [SwapFeeProviderView] = []

    private var swapLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.backgroundColor = UIColor.init(red: 74, green: 74, blue: 74)

        return view
    }()
    private var stackView: UIStackView = [UIView]([]).asStackView(axis: .vertical)
    private var swapLineConstraints: [NSLayoutConstraint] = []
    private var cancelable = Set<AnyCancellable>()

    init(viewModel: SwapFeesViewModel) {
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

    private func bind(viewModel: SwapFeesViewModel) {
        let views = viewModel.providersViewModels
            .receive(on: RunLoop.main)
            .map { $0.map { viewModel in SwapFeeProviderView(viewModel: viewModel) } }
            .share()
            .eraseToAnyPublisher()

        let swapLineConstraints = views.map { [swapLine, stackView] views -> [NSLayoutConstraint] in
            if views.isEmpty {
                return []
            } else {
                return [
                    swapLine.topAnchor.constraint(equalTo: views[0].centerYAnchor),
                    swapLine.bottomAnchor.constraint(equalTo: views[views.count - 1].centerYAnchor),
                    swapLine.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 4.5)
                ]
            }
        }.eraseToAnyPublisher()

        views.sink { [stackView] views in
            stackView.removeAllArrangedSubviews()
            stackView.addArrangedSubviews(views)
        }.store(in: &cancelable)

        swapLineConstraints.sink { [weak self] constraints in
            guard let strongSelf = self else { return }
            NSLayoutConstraint.deactivate(strongSelf.swapLineConstraints)

            strongSelf.swapLineConstraints = constraints
            NSLayoutConstraint.activate(constraints)
        }.store(in: &cancelable)
    } 

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
