//
//  SwitchTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

protocol SwitchTableViewCellDelegate: class {
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

    private let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.translatesAutoresizingMaskIntoConstraints = false
        return switchView
    }()
    
    var isOn: Bool {
        get { return switchView.isOn }
        set { switchView.isOn = newValue }
    }

    weak var delegate: SwitchTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        switchView.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        
        selectionStyle = .none
        accessoryType = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(iconImageView)
        contentView.addSubview(switchView)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            iconImageView.bottomAnchor.constraint(greaterThanOrEqualTo: contentView.bottomAnchor, constant: -10),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: switchView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            switchView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    @objc private func switchChanged(_ sender: UISwitch) {
        delegate?.cell(self, switchStateChanged: sender.isOn)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(viewModel: SwitchTableViewCellViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleTextColor
        iconImageView.image = viewModel.icon
        switchView.isOn = viewModel.value
    }
}
