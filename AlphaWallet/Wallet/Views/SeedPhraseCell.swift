// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class SeedPhraseCell: UICollectionViewCell {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let horizontalMargin = CGFloat(20)
        let verticalMargin = CGFloat(10)
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: contentView, edgeInsets: .init(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SeedPhraseCellViewModel) {
//        cornerRadius = 7

        label.textAlignment = .center
        label.font = viewModel.font
        label.text = viewModel.word
        if viewModel.isSelected {
            contentView.backgroundColor = viewModel.selectedBackgroundColor
            backgroundColor = viewModel.selectedBackgroundColor
            label.textColor = viewModel.selectedTextColor
        } else {
            contentView.backgroundColor = viewModel.backgroundColor
            backgroundColor = viewModel.backgroundColor
            label.textColor = viewModel.textColor
        }
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 4
        contentView.layer.borderColor = Colors.borderGrayColor.cgColor
        contentView.layer.borderWidth = 1
    }
}
