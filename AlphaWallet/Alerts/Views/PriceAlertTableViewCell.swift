//
//  PriceAlertTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.11.2022.
//

import UIKit

protocol PriceAlertTableViewCellDelegate: AnyObject {
    func cell(_ cell: PriceAlertTableViewCell, didToggle value: Bool, indexPath: IndexPath)
}

class PriceAlertTableViewCell: UITableViewCell {
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private lazy var switchButton: UISwitch = {
        let button = UISwitch()
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    weak var delegate: PriceAlertTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero

        let stackView = [
            .spacerWidth(16),
            iconImageView,
            .spacerWidth(16),
            titleLabel,
            .spacerWidth(16, flexible: true),
            switchButton,
            .spacerWidth(16),
        ].asStackView(axis: .horizontal, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 14, left: 0, bottom: 14, right: 0))
        ])

        switchButton.addTarget(self, action: #selector(toggleSelectionState), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: PriceAlertTableViewCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.attributedText = viewModel.titleAttributedString
        switchButton.isEnabled = viewModel.isSelected
    }

    @objc private func toggleSelectionState(_ sender: UISwitch) {
        guard let indexPath = indexPath else { return }
        delegate?.cell(self, didToggle: sender.isEnabled, indexPath: indexPath)
    }
}
