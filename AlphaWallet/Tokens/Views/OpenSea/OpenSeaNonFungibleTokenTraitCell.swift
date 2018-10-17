// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenTraitCell: UICollectionViewCell {
    static let identifier = "OpenSeaNonFungibleTokenTraitCell"
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentHuggingPriority(.required, for: .vertical)

        let col0 = iconImageView
        let col1 = [
            valueLabel,
            nameLabel,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        col1.translatesAutoresizingMaskIntoConstraints = false

        let mainStackView = [col0, col1].asStackView(alignment: .center)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: OpenSeaNonFungibleTokenAttributeCellViewModel) {
        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor
        nameLabel.backgroundColor = viewModel.backgroundColor

        nameLabel.font = viewModel.nameFont
        valueLabel.font = viewModel.valueFont

        nameLabel.text = viewModel.name
        valueLabel.text = viewModel.value
        iconImageView.image = viewModel.image
    }
}
