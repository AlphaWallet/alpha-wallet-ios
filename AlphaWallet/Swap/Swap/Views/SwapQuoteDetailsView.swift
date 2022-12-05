//
//  SwapQuoteDetailsView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

protocol SwapQuoteDetailsViewDelegate: AnyObject {
    func changeSwapRouteSelected(in view: SwapQuoteDetailsView)
}

final class SwapQuoteDetailsView: UIView {
    private lazy var quoteHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "Quote Details"))
        let button = view.enableTapAction(title: "Change")
        button.addTarget(self, action: #selector(changeSwapRouteSelected), for: .touchUpInside)

        return view
    }()
    private static var fieldEdgeInsets: UIEdgeInsets {
        return .init(
            top: 0,
            left: ScreenChecker.size(big: 20, medium: 20, small: 16),
            bottom: 0,
            right: ScreenChecker.size(big: 20, medium: 20, small: 16))
    }

    private lazy var exchangeView = SwapQuoteFieldView(edgeInsets: SwapQuoteDetailsView.fieldEdgeInsets, viewModel: viewModel.exchangeViewModel)
    private lazy var totalFeeView = SwapQuoteFieldView(edgeInsets: SwapQuoteDetailsView.fieldEdgeInsets, viewModel: viewModel.totalFeeViewModel)
    private lazy var currentPriceView = SwapQuoteFieldView(edgeInsets: SwapQuoteDetailsView.fieldEdgeInsets, viewModel: viewModel.currentPriceViewModel)
    private lazy var minimumReceivedView = SwapQuoteFieldView(edgeInsets: SwapQuoteDetailsView.fieldEdgeInsets, viewModel: viewModel.minimumReceivedViewModel)
    private lazy var swapFeesView = SwapStepsView(viewModel: viewModel.swapStepsViewModel)

    private lazy var toggleFeesButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints =  false
        button.setTitle("Show", for: .normal)
        button.setTitle("Hide", for: .selected)
        button.widthAnchor.constraint(equalToConstant: ScreenChecker.size(big: 50, medium: 50, small: 44)).isActive = true
        button.tintColor = Configuration.Color.Semantic.tableViewHeaderBackground
        button.setTitleColor(Colors.appTint, for: .normal)
        button.setTitleColor(Colors.appTint, for: .selected)

        return button
    }()

    private let viewModel: SwapQuoteDetailsViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var toggleFeesBackgroundView: UIView = [toggleFeesButton, .spacerWidth(ScreenChecker.size(big: 20, medium: 20, small: 16))].asStackView()

    weak var delegate: SwapQuoteDetailsViewDelegate?

    init(viewModel: SwapQuoteDetailsViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackview = [
            quoteHeaderView.adjusted(adjusment: ScreenChecker.size(big: 20, medium: 20, small: 16)),
            UIView.separator(),
            exchangeView,
            UIView.separator(),
            [totalFeeView, toggleFeesBackgroundView].asStackView(),
            UIView.separator(),
            swapFeesView,
            currentPriceView,
            UIView.separator(),
            minimumReceivedView
        ].asStackView(axis: .vertical)
        stackview.translatesAutoresizingMaskIntoConstraints =  false

        addSubview(stackview)

        NSLayoutConstraint.activate([
            stackview.anchorsConstraint(to: self),
            quoteHeaderView.heightAnchor.constraint(equalToConstant: ScreenChecker.size(big: 50, medium: 50, small: 44)),
        ])

        toggleFeesButton.addTarget(self, action: #selector(toggleFeesSelected), for: .touchUpInside)
        bind(viewModel: viewModel)
        swapFeesView.isHidden = true
        backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground
    }

    private func bind(viewModel: SwapQuoteDetailsViewModel) {
        let stepsOutput = viewModel.swapStepsViewModel.transform(input: .init())
        stepsOutput.areFeesHidden
            .sink { [toggleFeesBackgroundView] in toggleFeesBackgroundView.isHidden = $0 }
            .store(in: &cancelable)

        let output = viewModel.transform(input: .init())
        output.isHidden
            .sink { [weak self] in self?.isHidden = $0 }
            .store(in: &cancelable)
    } 

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleFeesSelected(_ sender: UIButton) {
        sender.isSelected.toggle()
        swapFeesView.isHidden.toggle()
    }

    @objc private func changeSwapRouteSelected(_ sender: UIButton) {
        delegate?.changeSwapRouteSelected(in: self)
    }
}
