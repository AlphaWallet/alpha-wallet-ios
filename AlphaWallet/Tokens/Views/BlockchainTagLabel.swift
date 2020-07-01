//
//  BlockchainTagLabel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit

class BlockchainTagLabel: UIView {

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: Screen.TokenCard.Metric.blockChainTagHeight),
            label.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 10, bottom: 0, right: 10)),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: BlockchainTagLabelViewModel) {
        backgroundColor = viewModel.blockChainNameBackgroundColor
        layer.cornerRadius = viewModel.blockChainNameCornerRadius
        isHidden = viewModel.blockChainNameLabelHidden

        label.textAlignment = viewModel.blockChainNameTextAlignment
        label.textColor = viewModel.blockChainNameColor
        label.font = viewModel.blockChainNameFont
        label.text = viewModel.blockChainTag
    }
}
