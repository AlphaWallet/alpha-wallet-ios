// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class SeedPhraseCell: UICollectionViewCell {
    static let identifier = "SeedPhraseCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let horizontalMargin = CGFloat(20)
        let verticalMargin = CGFloat(10)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalMargin),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalMargin),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SeedPhraseCellViewModel) {
        cornerRadius = 7
        contentView.backgroundColor = viewModel.backgroundColor
        backgroundColor = viewModel.backgroundColor

        label.textColor = viewModel.textColor
        label.textAlignment = .center
        label.font = viewModel.font
        label.text = viewModel.word
    }
}
