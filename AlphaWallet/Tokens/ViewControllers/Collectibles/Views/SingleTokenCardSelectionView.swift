//
//  SingleTokenCardSelectionView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

struct SingleTokenCardSelectionViewModel {
    var backgroundColor: UIColor = Colors.appTint

    var selectedAmount: Int? {
        tokenHolder.selectedCount(tokenId: tokenId)
    }

    var isSelected: Bool {
        tokenHolder.isSelected(tokenId: tokenId)
    }

    var isHidden: Bool {
        //TODO check correct?
        return tokenHolder.token(tokenId: tokenId)?.amount == nil
    }

    let tokenId: TokenId
    let tokenHolder: TokenHolder

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
    }

    var selectedAmountAttributedString: NSAttributedString? {
        guard let amount = selectedAmount else { return nil }

        return .init(string: "\(amount)", attributes: [
            .font: Fonts.semibold(size: 20),
            .foregroundColor: Colors.appWhite
        ])
    }
}

class SingleTokenCardSelectionView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    init() {
        super.init(frame: .zero)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 48),
            widthAnchor.constraint(equalToConstant: 48),
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    func configure(viewModel: SingleTokenCardSelectionViewModel) {
        backgroundColor = viewModel.backgroundColor
        titleLabel.attributedText = viewModel.selectedAmountAttributedString
        isHidden = viewModel.isHidden
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.width / 2.0
    }
}

