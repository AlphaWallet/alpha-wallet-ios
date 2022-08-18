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
        view.backgroundColor = Configuration.Color.Semantic.popupSeparator

        return view
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = .clear
        titleLabel.textColor = Configuration.Color.Semantic.popupPrimaryFont
       return titleLabel
    }()

    let iconImageView: ImageView = {
        let imageView = ImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 30),
            imageView.heightAnchor.constraint(equalToConstant: 30)
        ])

        return imageView
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
        view.backgroundColor = Configuration.Color.Semantic.popupSwipeIndicator
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
        addSubview(titleLabel)
        addSubview(iconImageView)
        addSubview(closeButton)
        addSubview(swipeIndicatorView)

        NSLayoutConstraint.activate([
            swipeIndicatorView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            swipeIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.headerHeight)
        ])

        configure(viewModel: viewModel)
    }

    func configure(viewModel: ConfirmationHeaderViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle
        iconImageView.image = viewModel.icon
        backgroundColor = viewModel.backgroundColor
        separatorLine.isHidden = viewModel.isMinimalMode
        swipeIndicatorView.isHidden = viewModel.swipeIndicationHidden
    }

    required init?(coder: NSCoder) {
        return nil
    } 
}
