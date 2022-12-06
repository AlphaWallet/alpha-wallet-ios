//
//  SwapQuoteFieldView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

final class SwapQuoteFieldView: UIView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    private var cancelable = Set<AnyCancellable>()
    private let viewModel: SwapQuoteFieldViewModel

    init(edgeInsets: UIEdgeInsets, viewModel: SwapQuoteFieldViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints =  false

        let stackview = [titleLabel, .spacerWidth(flexible: true), valueLabel].asStackView()
        stackview.translatesAutoresizingMaskIntoConstraints =  false

        addSubview(stackview)

        NSLayoutConstraint.activate([
            stackview.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            titleLabel.leadingAnchor.constraint(equalTo: stackview.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: stackview.trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: ScreenChecker.size(big: 60, medium: 60, small: 44))
        ])

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    } 

    private func bind(viewModel: SwapQuoteFieldViewModel) {
        cancelable.cancellAll()

        titleLabel.attributedText = viewModel.titleAttributedString
        backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground

        let output = viewModel.transform(input: .init())
        output.value
            .sink { [weak valueLabel] in valueLabel?.attributedText = $0 }
            .store(in: &cancelable)

        output.isHidden
            .sink { [weak self] in self?.isHidden = $0 }
            .store(in: &cancelable)
    }
}
