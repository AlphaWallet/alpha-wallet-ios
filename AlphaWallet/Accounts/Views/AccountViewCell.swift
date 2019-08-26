// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol AccountViewCellDelegate: class {
    func accountViewCell(_ cell: AccountViewCell, didTapInfoViewForAccount _: Wallet)
}

class AccountViewCell: UITableViewCell {
    static let identifier = "AccountViewCell"

    var infoButton = UIButton(type: .infoLight)
    var activeIcon = UIImageView(image: R.image.ticket_bundle_checked())
    var watchIcon = UIImageView(image: R.image.glasses())
    var addressLabel = UILabel()
    var balanceLabel = UILabel()
    weak var delegate: AccountViewCellDelegate?
    var account: Wallet?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        activeIcon.contentMode = .scaleAspectFit

        addressLabel.lineBreakMode = .byTruncatingMiddle

        infoButton.addTarget(self, action: #selector(infoAction), for: .touchUpInside)

        let leftStackView = [
            balanceLabel,
            addressLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let rightStackView = [infoButton].asStackView()

        let stackView = [activeIcon, leftStackView, watchIcon, rightStackView].asStackView(spacing: 15, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        activeIcon.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        addressLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        infoButton.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        infoButton.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        watchIcon.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        watchIcon.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        watchIcon.setContentHuggingPriority(UILayoutPriority.required, for: .vertical)
        watchIcon.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            activeIcon.widthAnchor.constraint(equalToConstant: 44),

            watchIcon.widthAnchor.constraint(lessThanOrEqualToConstant: 18),
            watchIcon.heightAnchor.constraint(lessThanOrEqualToConstant: 18),

            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 7, left: StyleLayout.sideMargin, bottom: 7, right: StyleLayout.sideMargin)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func infoAction() {
        guard let account = account else { return }
        delegate?.accountViewCell(self, didTapInfoViewForAccount: account)
    }

    func configure(viewModel: AccountViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        activeIcon.isHidden = !viewModel.showActiveIcon

        balanceLabel.font = viewModel.balanceFont
        balanceLabel.text = viewModel.balance

        addressLabel.font = viewModel.addressFont
        addressLabel.textColor = viewModel.addressTextColor
        addressLabel.text = viewModel.address.eip55String

        infoButton.tintColor = Colors.appBackground

        watchIcon.isHidden = !viewModel.showWatchIcon
    }
}
