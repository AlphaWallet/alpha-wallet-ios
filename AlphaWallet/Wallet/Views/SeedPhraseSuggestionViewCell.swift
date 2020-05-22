//
//  SeedPhraseSuggestionViewCell.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 02/05/20.
//
import UIKit

class SeedPhraseSuggestionViewCell: UICollectionViewCell {
    static let identifier = "SeedPhraseSuggestionViewCell"

    private let viewContainer: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.alabaster()
        view.layer.cornerRadius = 4
        return view
    }()

    let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = R.color.mine()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)

        viewContainer.translatesAutoresizingMaskIntoConstraints = false
        viewContainer.addSubview(textLabel)
        contentView.addSubview(viewContainer)

        NSLayoutConstraint.activate([
            viewContainer.anchorsConstraint(to: contentView),
            textLabel.anchorsConstraint(to: viewContainer, margin: 10),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(word: String) {
        textLabel.text = word
    }
}
