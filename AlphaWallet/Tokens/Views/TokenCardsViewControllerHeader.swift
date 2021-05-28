// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TokenCardsViewControllerHeaderDelegate: class {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader)
}

class TokenCardsViewControllerHeader: UIView {
    static let height = CGFloat(90)

    private let titleLabel = UILabel()
    //TODO rename? Button now
    private let blockchainLabel = UIButton(type: .system)
    private let blockChainTagLabel = UILabel()

    weak var delegate: TokenCardsViewControllerHeaderDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        blockchainLabel.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)

        blockChainTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        blockChainTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        let bottomRowStack = [blockchainLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15)
        let stackView = [
            titleLabel,
            bottomRowStack
        ].asStackView(axis: .vertical, spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 16, left: 16, bottom: 21, right: 21))
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
