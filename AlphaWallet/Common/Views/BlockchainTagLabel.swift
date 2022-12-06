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
        label.textAlignment = .center
        label.textColor = Screen.TokenCard.Color.blockChainName
        label.font = Screen.TokenCard.Font.blockChainName
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        
        return label
    }()
    private var heightConstraint: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        heightConstraint = heightAnchor.constraint(equalToConstant: DataEntry.Metric.BlockChainTag.height)
        
        NSLayoutConstraint.activate([
            heightConstraint,
            label.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 10, bottom: 0, right: 10)),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = DataEntry.Metric.BlockChainTag.cornerRadius
    }

    func configure(viewModel: BlockchainTagLabelViewModel) {
        backgroundColor = viewModel.backgroundColor
        isHidden = viewModel.isHidden

        if isHidden {
            NSLayoutConstraint.deactivate([heightConstraint])
        } else {
            NSLayoutConstraint.activate([heightConstraint])
        }

        label.text = viewModel.blockChainTag
    }
}
