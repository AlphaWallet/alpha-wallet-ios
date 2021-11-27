//
//  ConfirmationHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.02.2021.
//

import UIKit

class ConfirmationHeaderView: UIView {
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        return titleLabel
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentMode = .scaleAspectFit
        button.setImage(R.image.close(), for: .normal)

        return button
    }()

    private let swipeIndicatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Colors.black.withAlphaComponent(0.2)
        view.cornerRadius = 2.5

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 36),
            view.heightAnchor.constraint(equalToConstant: 5),
        ])

        return view
    }()

    init(viewModel: ConfirmationHeaderViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(separatorLine)
        addSubview(closeButton)
        addSubview(titleLabel)
        addSubview(swipeIndicatorView)

        NSLayoutConstraint.activate([
            swipeIndicatorView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            swipeIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.headerHeight)
        ])

        configure(viewModel: viewModel)
    }

    func configure(viewModel: ConfirmationHeaderViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle
        backgroundColor = viewModel.backgroundColor
        separatorLine.isHidden = viewModel.isMinimalMode
        swipeIndicatorView.isHidden = viewModel.swipeIndicationHidden
    }

    required init?(coder: NSCoder) {
        return nil
    } 
}
