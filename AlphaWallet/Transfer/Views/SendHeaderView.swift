// Copyright © 2018 Stormbird PTE. LTD.
import UIKit

class SendHeaderView: UIView {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let issuerLabel = UILabel()
    private let middleBorder = UIView()
    private var footerStackView: UIStackView?
    private let valuePercentageChangeValueLabel = UILabel()
    private let valuePercentageChangePeriodLabel = UILabel()
    private let valueChangeLabel = UILabel()
    private let valueChangeNameLabel = UILabel()
    private let valueLabel = UILabel()
    private let valueNameLabel = UILabel()

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

        let footerValuesStack = [valuePercentageChangeValueLabel, valueChangeLabel, valueLabel].asStackView(distribution: .equalCentering, spacing: 15)

        //Can't use a stack because we want to vertically center align the values and names labels
        let footerNamesHolder = UIView()
        valuePercentageChangePeriodLabel.translatesAutoresizingMaskIntoConstraints = false
        valueChangeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        valueNameLabel.translatesAutoresizingMaskIntoConstraints = false
        footerNamesHolder.addSubview(valuePercentageChangePeriodLabel)
        footerNamesHolder.addSubview(valueChangeNameLabel)
        footerNamesHolder.addSubview(valueNameLabel)

        footerStackView = [
            .spacer(height: 14),
            footerValuesStack,
            footerNamesHolder,
        ].asStackView(axis: .vertical, perpendicularContentHuggingPriority: .defaultLow)
        footerStackView?.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
            bottomRowStack,
            .spacer(height: 7),
            middleBorder,
            footerStackView!,
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

            footerNamesHolder.topAnchor.constraint(equalTo: valuePercentageChangePeriodLabel.topAnchor),
            footerNamesHolder.bottomAnchor.constraint(equalTo: valuePercentageChangePeriodLabel.bottomAnchor),
            valuePercentageChangePeriodLabel.centerYAnchor.constraint(equalTo: valueChangeNameLabel.centerYAnchor),
            valuePercentageChangePeriodLabel.centerYAnchor.constraint(equalTo: valueNameLabel.centerYAnchor),
            valuePercentageChangePeriodLabel.centerXAnchor.constraint(equalTo: valuePercentageChangeValueLabel.centerXAnchor),
            valueChangeNameLabel.centerXAnchor.constraint(equalTo: valueChangeLabel.centerXAnchor),
            valueNameLabel.centerXAnchor.constraint(equalTo: valueLabel.centerXAnchor),
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

        footerStackView?.isHidden = !viewModel.showAlternativeAmount
    }
}
