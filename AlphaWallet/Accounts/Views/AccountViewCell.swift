// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class AccountViewCell: UITableViewCell {
    private let addressOrEnsName = UILabel()
    private let apprecation24hourLabel = UILabel()
    private let balanceLabel = UILabel()
    private let blockieImageView = BlockieImageView(size: .init(width: 40, height: 40))
    private lazy var selectedIndicator: UIView = {
        let indicator = UIView()
        indicator.layer.cornerRadius = DataEntry.Metric.SelectionIndicator.width / 2.0
        indicator.borderWidth = 0.0
        indicator.backgroundColor = Configuration.Color.Semantic.indicator
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: DataEntry.Metric.SelectionIndicator.width),
            indicator.heightAnchor.constraint(equalToConstant: DataEntry.Metric.SelectionIndicator.height)
        ])
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        return indicator
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        addressOrEnsName.lineBreakMode = .byTruncatingMiddle
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        let leftStackView = [
            [balanceLabel, apprecation24hourLabel].asStackView(spacing: 10),
            addressOrEnsName
        ].asStackView(axis: .vertical)

        let stackView = [blockieImageView, leftStackView, .spacerWidth(10)].asStackView(spacing: 12, alignment: .top)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        contentView.addSubview(selectedIndicator)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -25),
            selectedIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectedIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DataEntry.Metric.SelectionIndicator.leadingOffset)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AccountViewModel) {
        accessoryView = UIImageView.chevronImageView
        selectedIndicator.isHidden = !viewModel.isSelected

        addressOrEnsName.attributedText = viewModel.addressOrEnsName
        blockieImageView.set(blockieImage: viewModel.blockieImage)
        balanceLabel.attributedText = viewModel.balance
        apprecation24hourLabel.attributedText = viewModel.apprecation24hour
    }
}
