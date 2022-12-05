//
//  SelectableSwapToolTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit

final class SelectableSwapToolTableViewCell: UITableViewCell {

    private lazy var iconView: RoundedImageView = {
        let iconView = RoundedImageView(size: CGSize(width: 40, height: 40))
        return iconView
    }()

    private let accessoryImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let infoView: InformationView = {
        let view = InformationView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(iconView)
        contentView.addSubview(infoView)
        contentView.addSubview(accessoryImageView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: contentView.topAnchor, multiplier: 1.0),
            iconView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: contentView.bottomAnchor, multiplier: 1.0),

            infoView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16.0),
            infoView.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor),
            infoView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: contentView.topAnchor, multiplier: 1.0),
            infoView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: contentView.bottomAnchor, multiplier: 1.0),

            accessoryImageView.widthAnchor.constraint(equalToConstant: 30.0),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 30.0),
            accessoryImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20.0),
            accessoryImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accessoryImageView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: contentView.topAnchor, multiplier: 1.0),
            accessoryImageView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: contentView.bottomAnchor, multiplier: 1.0)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func configure(viewModel: SelectableSwapToolTableViewCellViewModel) {
        accessoryImageView.image = viewModel.accessoryImageView
        iconView.setImage(url: viewModel.logoUrl, placeholder: viewModel.logoPlaceholder)
        selectionStyle = viewModel.selectionStyle
        backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        infoView.configure(viewModel: viewModel.infoViewModel)
    }
}

struct InformationViewModel {
    let title: NSAttributedString
    let description: NSAttributedString
}

fileprivate class InformationView: UIView {
    private let titleTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private let descriptionTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleTextLabel)
        addSubview(descriptionTextLabel)

        NSLayoutConstraint.activate([
            titleTextLabel.topAnchor.constraint(equalTo: topAnchor),
            titleTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleTextLabel.bottomAnchor.constraint(equalTo: descriptionTextLabel.topAnchor),
            descriptionTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            descriptionTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            descriptionTextLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: InformationViewModel) {
        titleTextLabel.attributedText = viewModel.title
        descriptionTextLabel.attributedText = viewModel.description
    }
}
