//
//  TransactionSectionHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.11.2022.
//

import UIKit

class TransactionSectionHeaderView: UITableViewHeaderFooterView {
    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.sizeToFit()
        titleLabel.textColor = Configuration.Color.Semantic.defaultForegroundText
        titleLabel.font = Fonts.semibold(size: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        return titleLabel
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        contentView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        contentView.addSubview(titleLabel)

        let edgeInsets: UIEdgeInsets = .init(
            top: ScreenChecker.size(big: 13, medium: 18, small: 13),
            left: ScreenChecker.size(big: 20, medium: 20, small: 15),
            bottom: ScreenChecker.size(big: 16, medium: 16, small: 11),
            right: 0)

        NSLayoutConstraint.activate([
            titleLabel.anchorsConstraint(to: contentView, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}
