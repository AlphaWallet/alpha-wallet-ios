//
//  SwapRouteSummaryView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.09.2022.
//

import UIKit
import Combine

class SwapRouteSummaryView: UIView {
    private let amountToSwapHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private let amountToSwapLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private let currentPriceHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private let currentPriceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private let timeoutLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    
    private lazy var toTokenServerImageView: RoundedImageView = {
        let iconView = RoundedImageView(size: DataEntry.Metric.ImageView.serverIconSize)
        return iconView
    }()

    private var cancelable = Set<AnyCancellable>()

    init(edgeInsets: UIEdgeInsets, viewModel: SwapRouteSummaryViewModel) {
        super.init(frame: .zero)

        let stackView = [
            amountToSwapHeaderLabel,
            .spacer(height: 5),
            [amountToSwapLabel, toTokenServerImageView].asStackView(axis: .horizontal, spacing: 5, alignment: .leading),
            .spacer(height: 10),
            currentPriceHeaderLabel,
            .spacer(height: 5),
            currentPriceLabel,
            .spacer(height: 10),
            timeoutLabel
        ].asStackView(axis: .vertical, alignment: .leading)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate(stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets))

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind(viewModel: SwapRouteSummaryViewModel) {
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        let output = viewModel.transform(input: .init())
        output.viewState.sink { [weak self] state in
            self?.amountToSwapHeaderLabel.attributedText = state.amountToHeader
            self?.amountToSwapLabel.attributedText = state.amountTo
            self?.currentPriceHeaderLabel.attributedText = state.currentPriceHeader
            self?.currentPriceLabel.attributedText = state.currentPrice
            self?.timeoutLabel.isHidden = true
            self?.toTokenServerImageView.image = state.serverImage
        }.store(in: &cancelable)
    }
}
