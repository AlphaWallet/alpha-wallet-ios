//
//  WallerConnectRawView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.07.2020.
//

import UIKit

class WalletConnectRowView: UIView {
    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let topSeparatorLine: UIView = {
        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false

        return separatorLine
    }()

    private let bottomSeparatorLine: UIView = {
        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false

        return separatorLine
    }()

    init() {
        super.init(frame: .zero)

        let stackView = [
            topSeparatorLine,
            [.spacerWidth(16), textLabel, detailsLabel, .spacerWidth(16)].asStackView(),
            bottomSeparatorLine
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 60),
            textLabel.widthAnchor.constraint(equalToConstant: 100),
            topSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            bottomSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            stackView.anchorsConstraint(to: self)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: WallerConnectRawViewModel) {
        textLabel.text = viewModel.text
        textLabel.font = viewModel.textLabelFont
        textLabel.textColor = viewModel.textLabelTextColor

        detailsLabel.text = viewModel.details
        detailsLabel.font = viewModel.detailsLabelFont
        detailsLabel.textColor = viewModel.detailsLabelTextColor

        topSeparatorLine.backgroundColor = viewModel.separatorLineColor
        bottomSeparatorLine.backgroundColor = viewModel.separatorLineColor
        hideSeparators(for: viewModel.hideSeparatorOptions)
    }

    private func hideSeparators(for options: HideSeparatorOption) {
        switch options {
        case .top:
            bottomSeparatorLine.isHidden = false
            topSeparatorLine.isHidden = true
        case .bottom:
            topSeparatorLine.isHidden = false
            bottomSeparatorLine.isHidden = true
        case .both:
            bottomSeparatorLine.isHidden = true
            topSeparatorLine.isHidden = true
        case .none:
            bottomSeparatorLine.isHidden = false
            topSeparatorLine.isHidden = false
        }
    }
}

