// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LocaleViewCell: UITableViewCell {
    static let identifier = "LocaleViewCell"

    private let selectedIcon = UIImageView(image: R.image.ticket_bundle_checked())
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectedIcon.contentMode = .scaleAspectFit

        let stackView = [selectedIcon, nameLabel].asStackView(spacing: 15, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        selectedIcon.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            selectedIcon.widthAnchor.constraint(equalToConstant: 44),

            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 7, left: StyleLayout.sideMargin, bottom: 7, right: StyleLayout.sideMargin)),
            stackView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: LocaleViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        selectedIcon.image = viewModel.selectionIcon

        nameLabel.font = viewModel.localeFont
        nameLabel.text = viewModel.localeName
    }
}
