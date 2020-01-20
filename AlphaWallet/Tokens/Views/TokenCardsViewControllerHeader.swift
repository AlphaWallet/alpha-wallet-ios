// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TokenCardsViewControllerHeaderDelegate: class {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader)
}

class TokenCardsViewControllerHeader: UIView {
    static let height = CGFloat(90)

    private let background = UIView()
    private let titleLabel = UILabel()
    //TODO rename? Button now
    private let blockchainLabel = UIButton(type: .system)
    private let separator = UILabel()
    private let issuerLabel = UILabel()
    private let blockChainTagLabel = UILabel()

    weak var delegate: TokenCardsViewControllerHeaderDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        blockchainLabel.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)

        blockChainTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        blockChainTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        let bottomRowStack = [blockchainLabel, separator, issuerLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15)
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
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -16),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokensCardViewControllerHeaderViewModel) {
        frame = CGRect(x: 0, y: 0, width: 300, height: TokenCardsViewControllerHeader.height)
        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.setTitleColor(viewModel.subtitleColor, for: .normal)
        blockchainLabel.titleLabel?.font = viewModel.subtitleFont
        blockchainLabel.setTitle(viewModel.blockChainName, for: .normal)

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        let issuer = viewModel.issuer
        if issuer.isEmpty {
            issuerLabel.text = ""
        } else {
            issuerLabel.text = issuer
        }
        separator.textColor = viewModel.subtitleColor
        separator.font = viewModel.subtitleFont
        separator.text = viewModel.issuerSeparator

        blockChainTagLabel.textAlignment = viewModel.blockChainNameTextAlignment
        blockChainTagLabel.cornerRadius = 7
        blockChainTagLabel.backgroundColor = viewModel.blockChainNameBackgroundColor
        blockChainTagLabel.textColor = viewModel.blockChainNameColor
        blockChainTagLabel.font = viewModel.blockChainNameFont
        blockChainTagLabel.text = viewModel.blockChainTag
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(inHeaderView: self)
    }
}
