// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class HelpViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let iconImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        _  = CGFloat(7)
        _  = CGFloat(4)
        NSLayoutConstraint.activate([
            iconImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -21),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        selectionStyle = .none
        backgroundColor = Colors.appBackground

        contentView.backgroundColor = Colors.appBackground

        iconImageView.image = R.image.info_accessory()

        textLabel?.textColor = Colors.appText
        textLabel?.font = Fonts.light(size: 18)!
        textLabel?.text = text
    }
}
