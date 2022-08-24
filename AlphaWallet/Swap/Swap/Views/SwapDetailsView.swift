//
//  SwapDetailsView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

final class SwapDetailsView: UIView {

    private lazy var totalFeeView = FieldView(edgeInsets: .init(top: 0, left: 20, bottom: 0, right: 20))
    private lazy var currentPriceView = FieldView(edgeInsets: .init(top: 0, left: 20, bottom: 0, right: 20))
    private lazy var minimumReceivedView = FieldView(edgeInsets: .init(top: 0, left: 20, bottom: 0, right: 20))
    private lazy var swapFeesView = SwapStepsView(viewModel: viewModel.swapStepsViewModel)

    private lazy var toggleFeesButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints =  false
        button.setTitle("Show", for: .normal)
        button.setTitle("Hide", for: .selected)
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        button.tintColor = R.color.alabaster()!
        button.setTitleColor(Colors.appTint, for: .normal)
        button.setTitleColor(Colors.appTint, for: .selected)

        return button
    }()

    private var viewModel: SwapDetailsViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var toggleFeesBackgroundView: UIView = [toggleFeesButton, .spacerWidth(20)].asStackView()

    init(viewModel: SwapDetailsViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackview = [
            [totalFeeView, toggleFeesBackgroundView].asStackView(),
            .spacer(height: 1, backgroundColor: R.color.mercury()!),
            swapFeesView,
            currentPriceView,
            .spacer(height: 1, backgroundColor: R.color.mercury()!),
            minimumReceivedView
        ].asStackView(axis: .vertical)
        stackview.translatesAutoresizingMaskIntoConstraints =  false

        addSubview(stackview)

        NSLayoutConstraint.activate([
            stackview.anchorsConstraint(to: self),
        ])

        toggleFeesButton.addTarget(self, action: #selector(toggleFeesSelected), for: .touchUpInside)
        bind(viewModel: viewModel)
        swapFeesView.isHidden = true
        backgroundColor = viewModel.backgoundColor

        viewModel.swapStepsViewModel.hasProviders
            .sink { [toggleFeesBackgroundView] hasProviders in
                toggleFeesBackgroundView.isHidden = !hasProviders
            }.store(in: &cancelable)

        viewModel.isHidden
            .sink(receiveValue: { [weak self] isHidden in
                self?.isHidden = isHidden
            }).store(in: &cancelable)
    }

    private func bind(viewModel: SwapDetailsViewModel) {
        totalFeeView.bind(viewModel: viewModel.totalFeeViewModel)
        currentPriceView.bind(viewModel: viewModel.currentPriceViewModel)
        minimumReceivedView.bind(viewModel: viewModel.minimumReceivedViewModel)
    } 

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleFeesSelected(_ sender: UIButton) {
        sender.isSelected.toggle()
        swapFeesView.isHidden.toggle()
    }
}
