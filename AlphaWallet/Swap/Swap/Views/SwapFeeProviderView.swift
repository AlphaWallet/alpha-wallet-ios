//
//  SwapFeeProviderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

extension SwapFeesView {
    class SwapFeeProviderView: UIView {

        lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false

            return label
        }()

        lazy var valueLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false

            return label
        }()

        private var indicatorView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = UIColor.init(red: 74, green: 74, blue: 74)
            view.cornerRadius = 5
            view.heightAnchor.constraint(equalToConstant: 10).isActive = true
            view.widthAnchor.constraint(equalToConstant: 10).isActive = true

            return view
        }()

        private lazy var infoButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 16).isActive = true
            button.widthAnchor.constraint(equalToConstant: 16).isActive = true
            button.setImage(R.image.iconsSystemQuestionMark(), for: .normal)

            return button
        }()
        private var cancelable = Set<AnyCancellable>()

        init(viewModel: SwapFeesViewModel.SwapFeeProviderViewModel) {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false

            let stackview = [
                indicatorView, .spacerWidth(15), titleLabel, .spacerWidth(10), infoButton, .spacerWidth(flexible: true), valueLabel
            ].asStackView(alignment: .center)
            stackview.translatesAutoresizingMaskIntoConstraints =  false

            addSubview(stackview)

            NSLayoutConstraint.activate([
                stackview.anchorsConstraint(to: self),
                valueLabel.trailingAnchor.constraint(equalTo: stackview.trailingAnchor),
                heightAnchor.constraint(greaterThanOrEqualToConstant: 27),
            ])

            bind(viewModel: viewModel)
            backgroundColor = viewModel.backgroundColor
        }

        private func bind(viewModel: SwapFeesViewModel.SwapFeeProviderViewModel) {
            viewModel.nameAttributedString.sink { [titleLabel] attributedString in
                titleLabel.attributedText = attributedString
            }.store(in: &cancelable)

            viewModel.feeAttributedString.sink { [valueLabel] attributedString in
                valueLabel.attributedText = attributedString
            }.store(in: &cancelable)
        }

        required init?(coder: NSCoder) {
            return nil
        }
    }
}
