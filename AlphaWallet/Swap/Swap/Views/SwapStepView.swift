//
//  SwapFeeProviderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit

extension SwapStepsView {
    class SwapStepView: UIView {

        private lazy var toolLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false

            return label
        }()

        private lazy var descriptionLabel: UILabel = {
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
            button.alpha = 0

            return button
        }()
        private let subProviderViews: UIStackView = [UIView]().asStackView(axis: .vertical)

        init(viewModel: SwapStepsViewModel.SwapStepViewModel) {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false

            let stackview = [
                [indicatorView, .spacerWidth(15), toolLabel, .spacerWidth(10), infoButton, .spacerWidth(flexible: true)].asStackView(alignment: .center),
                [.spacerWidth(25), descriptionLabel].asStackView(alignment: .center),
                [.spacerWidth(35), subProviderViews].asStackView(alignment: .center),
            ].asStackView(axis: .vertical)
            stackview.translatesAutoresizingMaskIntoConstraints =  false

            addSubview(stackview)

            NSLayoutConstraint.activate([
                stackview.anchorsConstraint(to: self),
                heightAnchor.constraint(greaterThanOrEqualToConstant: 27),
            ])

            configure(viewModel: viewModel)
        }

        private func configure(viewModel: SwapStepsViewModel.SwapStepViewModel) {
            backgroundColor = viewModel.backgroundColor
            toolLabel.attributedText = viewModel.toolAttributedString
            descriptionLabel.attributedText = viewModel.descriptionAttributedString

            let subStepViews = viewModel.subSteps.map { SwapSubStepView(viewModel: $0) }
            subProviderViews.removeAllArrangedSubviews()
            subProviderViews.addArrangedSubviews(subStepViews)
        }

        required init?(coder: NSCoder) {
            return nil
        }
    }

    class SwapSubStepView: UIView {

        private lazy var descriptionLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 1

            return label
        }()

        init(viewModel: SwapStepsViewModel.SwapSubStepViewModel) {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(descriptionLabel)

            NSLayoutConstraint.activate([
                descriptionLabel.anchorsConstraint(to: self, edgeInsets: UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 10)),
            ])

            configure(viewModel: viewModel)
            backgroundColor = viewModel.backgroundColor
        }

        private func configure(viewModel: SwapStepsViewModel.SwapSubStepViewModel) {
            descriptionLabel.attributedText = viewModel.descriptionAttributedString
        }

        required init?(coder: NSCoder) {
            return nil
        }
    }
}
