// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ServerViewCell: UITableViewCell {
    static let identifier = "ServerViewCell"

    private let background = UIView()
    private let selectedIcon = UIImageView(image: R.image.ticket_bundle_checked())
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        selectedIcon.translatesAutoresizingMaskIntoConstraints = false
        selectedIcon.contentMode = .scaleAspectFit

        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [selectedIcon, nameLabel].asStackView(spacing: 15, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        selectedIcon.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(7)
        NSLayoutConstraint.activate([
            selectedIcon.widthAnchor.constraint(equalToConstant: 44),

            stackView.anchorsConstraint(to: background, margin: StyleLayout.sideMargin),

            background.anchorsConstraint(to: self, edgeInsets: .init(top: yMargin, left: xMargin, bottom: yMargin, right: xMargin)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ServerViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20
        background.borderColor = viewModel.contentsBorderColor
        background.borderWidth = viewModel.contentsBorderWidth

        selectedIcon.image = viewModel.selectionIcon

        nameLabel.font = viewModel.serverFont
        nameLabel.text = viewModel.serverName
    }
}
