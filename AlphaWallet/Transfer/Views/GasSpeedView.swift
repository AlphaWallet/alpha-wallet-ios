//
//  GasSpeedView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import UIKit
import AlphaWalletFoundation

class GasSpeedView: UIView {
    static let height: CGFloat = CGFloat(100)

    private let estimatedTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1

        return label
    }()

    private let speedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1

        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1

        return label
    }()

    private let gasPriceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1

        return label
    }()
    private lazy var selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    init() {
        super.init(frame: .zero)

        let col0 = [
            speedLabel,
            detailsLabel,
            gasPriceLabel,
        ].asStackView(axis: .vertical, alignment: .leading)

        let row = [.spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16), col0, estimatedTimeLabel, .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16)].asStackView(axis: .horizontal)

        let stackView = [
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20),
            row,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20)
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        addSubview(selectionImageView)

        NSLayoutConstraint.activate([
            estimatedTimeLabel.widthAnchor.constraint(equalToConstant: 100),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 1),
            selectionImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            selectionImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: GasSpeedViewModel) {
        backgroundColor = viewModel.backgroundColor

        speedLabel.attributedText = viewModel.titleAttributedString

        estimatedTimeLabel.textAlignment = .right
        estimatedTimeLabel.attributedText = viewModel.estimatedTimeAttributedString
        estimatedTimeLabel.isHidden = estimatedTimeLabel.attributedText == nil

        detailsLabel.attributedText = viewModel.detailsAttributedString
        detailsLabel.isHidden = detailsLabel.attributedText == nil

        gasPriceLabel.attributedText = viewModel.gasPriceAttributedString
        gasPriceLabel.isHidden = gasPriceLabel.attributedText == nil

        selectionImageView.image = viewModel.accessoryIcon
    }
}

