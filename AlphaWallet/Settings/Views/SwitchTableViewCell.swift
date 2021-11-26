//
//  SwitchTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

protocol SwitchTableViewCellDelegate: AnyObject {
    func cell(_ cell: SwitchTableViewCell, switchStateChanged isOn: Bool)
}

class SwitchTableViewCell: UITableViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let switchView: UIButton = {
        let switchView = UIButton(type: .custom)
        switchView.setImage(R.image.switchOff(), for: .normal)
        switchView.setImage(R.image.switchOn(), for: .selected)
        switchView.translatesAutoresizingMaskIntoConstraints = false
        return switchView
    }()

    var isOn: Bool {
        get { return switchView.isSelected }
        set { switchView.isSelected = newValue }
    }

    weak var delegate: SwitchTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        switchView.addTarget(self, action: #selector(switchChanged), for: .touchUpInside)

        selectionStyle = .none
        accessoryType = .none

        let stackView = [
            iconImageView, titleLabel, .spacerWidth(flexible: true), switchView
        ].asStackView(axis: .horizontal, spacing: 16, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 10, left: 16, bottom: 10, right: 20))
        ])
    }

    @objc private func switchChanged(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        delegate?.cell(self, switchStateChanged: sender.isSelected)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SwitchTableViewCellViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleTextColor
        iconImageView.image = viewModel.icon
        switchView.isSelected = viewModel.value
    }
}
