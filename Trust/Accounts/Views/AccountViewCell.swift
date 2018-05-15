// Copyright SIX DAY LLC. All rights reserved.
import TrustKeystore
import UIKit

protocol AccountViewCellDelegate: class {
    func accountViewCell(_ cell: AccountViewCell, didTapInfoViewForAccount _: Wallet)
}

class AccountViewCell: UITableViewCell {
    static let identifier = "AccountViewCell"

    let background = UIView()
    var infoButton = UIButton(type: .infoLight)
    var activeIcon = UIImageView(image: R.image.ticket_bundle_checked())
    var watchIcon = UIImageView(image: R.image.glasses())
    var addressLabel = UILabel()
    var balanceLabel = UILabel()
    weak var delegate: AccountViewCellDelegate?
    var account: Wallet? = nil

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        activeIcon.translatesAutoresizingMaskIntoConstraints = false
        activeIcon.contentMode = .scaleAspectFit

        balanceLabel.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.lineBreakMode = .byTruncatingMiddle

        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.addTarget(self, action: #selector(infoAction), for: .touchUpInside)

        let leftStackView = [
            balanceLabel,
            addressLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 6)
        leftStackView.translatesAutoresizingMaskIntoConstraints = false

        let rightStackView = [infoButton].asStackView()
        rightStackView.translatesAutoresizingMaskIntoConstraints = false

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

        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(7)
        NSLayoutConstraint.activate([
            activeIcon.widthAnchor.constraint(equalToConstant: 44),

            watchIcon.widthAnchor.constraint(lessThanOrEqualToConstant: 18),
            watchIcon.heightAnchor.constraint(lessThanOrEqualToConstant: 18),

            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: StyleLayout.sideMargin),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -StyleLayout.sideMargin),
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),
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

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20
        background.borderColor = viewModel.contentsBorderColor
        background.borderWidth = viewModel.contentsBorderWidth

        activeIcon.isHidden = !viewModel.showActiveIcon

        balanceLabel.font = viewModel.balanceFont
        balanceLabel.text = viewModel.balance

        addressLabel.font = viewModel.addressFont
        addressLabel.textColor = viewModel.addressTextColor
        addressLabel.text = viewModel.address

        infoButton.tintColor = Colors.appBackground

        watchIcon.isHidden = !viewModel.showWatchIcon
    }
}
