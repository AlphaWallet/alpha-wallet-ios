// Copyright © 2018 Stormbird PTE. LTD.
import UIKit

class SendHeaderView: UIView {
    let background = UIView()
    let titleLabel = UILabel()
    let blockchainLabel = UILabel()
    let issuerLabel = UILabel()

    let middleBorder = UIView()
    let valuePercentageChangeValueLabel = UILabel()
    let valuePercentageChangePeriodLabel = UILabel()
    let valueChangeLabel = UILabel()
    let valueChangeNameLabel = UILabel()
    let valueLabel = UILabel()
    let valueNameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valuePercentageChangeValueLabel.textAlignment = .center
        valuePercentageChangePeriodLabel.textAlignment = .center
        valueChangeLabel.textAlignment = .center
        valueChangeNameLabel.textAlignment = .center
        valueLabel.textAlignment = .center
        valueNameLabel.textAlignment = .center

        let bottomRowStack = [blockchainLabel, issuerLabel].asStackView(spacing: 15)

        let footerValuesStack = [valuePercentageChangeValueLabel, valueChangeLabel, valueLabel].asStackView(distribution: .fillEqually, spacing: 15)

        let footerNamesStack = [valuePercentageChangePeriodLabel, valueChangeNameLabel, valueNameLabel].asStackView(distribution: .fillEqually, spacing: 15)

        let footerStackView = [
            middleBorder,
            .spacer(height: 14),
            footerValuesStack,
            footerNamesStack,
        ].asStackView(axis: .vertical, perpendicularContentHuggingPriority: .defaultLow)
        footerStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
            bottomRowStack,
            .spacer(height: 7),
            footerStackView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        let backgroundWidthConstraint = background.widthAnchor.constraint(equalTo: widthAnchor)
        backgroundWidthConstraint.priority = .defaultHigh
        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.heightAnchor.constraint(equalTo: heightAnchor),
            backgroundWidthConstraint,

            middleBorder.heightAnchor.constraint(equalToConstant: 1),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 7),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -7),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SendHeaderViewViewModel) {
        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
        titleLabel.adjustsFontSizeToFitWidth = true

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        let issuer = viewModel.issuer
        if issuer.isEmpty {
            issuerLabel.text = ""
        } else {
            issuerLabel.text = "\(R.string.localizable.aWalletContentsIssuerTitle()): \(issuer)"
        }

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
