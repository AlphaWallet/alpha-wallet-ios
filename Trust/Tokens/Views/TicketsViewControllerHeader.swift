// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TicketsViewControllerHeader: UIView {
    let background = UIView()
    let titleLabel = UILabel()
    let blockchainLabel = UILabel()
    let separator = UILabel()
    let issuerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomRowStack = [blockchainLabel, separator, issuerLabel].asStackView(spacing: 15)
        let stackView = [
            titleLabel,
            bottomRowStack
        ].asStackView(axis: .vertical, spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        let backgroundWidthConstraint = background.widthAnchor.constraint(equalTo: widthAnchor)
        backgroundWidthConstraint.priority = .defaultHigh
        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            backgroundWidthConstraint,

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TicketsViewControllerHeaderViewModel) {
        frame = CGRect(x: 0, y: 0, width: 300, height: 90)
        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        let issuer = viewModel.issuer
        if issuer.isEmpty {
            issuerLabel.text = ""
        } else {
            issuerLabel.text = "\(R.string.localizable.aWalletContentsIssuerTitle()): \(issuer)"
        }

        separator.textColor = viewModel.subtitleColor
        separator.font = viewModel.subtitleFont
        separator.text = "|"
    }
}