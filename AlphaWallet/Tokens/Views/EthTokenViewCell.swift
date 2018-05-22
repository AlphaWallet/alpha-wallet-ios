// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class EthTokenViewCell: UITableViewCell {
    static let identifier = "EthTokenViewCell"

    let background = UIView()
    let titleLabel = UILabel()
    let blockchainLabel = UILabel()
    let separator = UILabel()
    let issuerLabel = UILabel()

    let middleBorder = UIView()
    let valuePercentageChangeValueLabel = UILabel()
    let valuePercentageChangePeriodLabel = UILabel()
    let valueChangeLabel = UILabel()
    let valueChangeNameLabel = UILabel()
    let valueLabel = UILabel()
    let valueNameLabel = UILabel()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        valuePercentageChangeValueLabel.textAlignment = .center
        valuePercentageChangePeriodLabel.textAlignment = .center
        valueChangeLabel.textAlignment = .center
        valueChangeNameLabel.textAlignment = .center
        valueLabel.textAlignment = .center
        valueNameLabel.textAlignment = .center

        let bottomRowStack = [blockchainLabel, separator, issuerLabel].asStackView(spacing: 15)
        let footerValuesStack = [valuePercentageChangeValueLabel, valueChangeLabel, valueLabel].asStackView(distribution: .fillEqually, spacing: 15)
        let footerNamesStack = [valuePercentageChangePeriodLabel, valueChangeNameLabel, valueNameLabel].asStackView(distribution: .fillEqually, spacing: 15)
        let footerStackView = [
            middleBorder,
            .spacer(height: 14),
            footerValuesStack,
            footerNamesStack,
        ].asStackView(axis: .vertical, perpendicularContentHuggingPriority: .defaultLow)
        let stackView = [
            titleLabel,
            bottomRowStack,
            footerStackView
        ].asStackView(axis: .vertical, spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(4)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),

            middleBorder.heightAnchor.constraint(equalToConstant: 1),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: EthTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20

        contentView.backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = "\(viewModel.amount) \(viewModel.title)"
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        issuerLabel.text = viewModel.issuer

        separator.textColor = viewModel.subtitleColor
        separator.font = viewModel.subtitleFont
        separator.text = ""

        middleBorder.backgroundColor = viewModel.borderColor

        valuePercentageChangePeriodLabel.textColor = viewModel.textColor
        valuePercentageChangePeriodLabel.font = viewModel.textLabelFont
        valuePercentageChangePeriodLabel.text = viewModel.valuePercentageChangePeriod
        valueChangeNameLabel.textColor = viewModel.textColor
        valueChangeNameLabel.font = viewModel.textLabelFont
        valueChangeNameLabel.text = viewModel.valueChangeName
        valueNameLabel.textColor = viewModel.textColor
        valueNameLabel.font = viewModel.textLabelFont
        valueNameLabel.text = viewModel.valueName

        valuePercentageChangeValueLabel.textColor = viewModel.valuePercentageChangeColor
        valuePercentageChangeValueLabel.font = viewModel.textValueFont
        valuePercentageChangeValueLabel.text = viewModel.valuePercentageChangeValue
        valueChangeLabel.textColor = viewModel.textColor
        valueChangeLabel.font = viewModel.textValueFont
        valueChangeLabel.text = viewModel.valueChange
        valueLabel.textColor = viewModel.textColor
        valueLabel.font = viewModel.textValueFont
        valueLabel.text = viewModel.value
    }
}
