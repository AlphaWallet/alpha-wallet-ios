//
//  SwapToolCollectionViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit

final class SwapToolCollectionViewCell: UICollectionViewCell {

    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(label)

        let horizontalMargin = CGFloat(16)
        let verticalMargin = CGFloat(8)
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: contentView, edgeInsets: .init(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SwapToolCollectionViewCellViewModel) {
        cornerRadius = 7
        backgroundColor = Configuration.Color.Semantic.periodButtonNormalText
        label.attributedText = viewModel.nameAttributedString
    }
}
