// Copyright © 2018 Stormbird PTE. LTD.
import UIKit

protocol SendHeaderViewDelegate: class {
    func didPressViewContractWebPage(inHeaderView: SendHeaderView)
}

class SendHeaderView: UIView {
    private let background = UIView()
    private let titleLabel = UILabel()
    //TODO rename? Button now
    private let blockchainLabel = UIButton(type: .system)
    private let issuerLabel = UILabel()
    private let blockChainTagLabel = UILabel()
    private let middleBorder = UIView()
    private var footerStackView: UIStackView?
    lazy private var viewsToShowOnlyIfAlternativeAmountsAreAvailable = {
        return [middleBorder, footerStackView!]
    }()
    private let valuePercentageChangeValueLabel = UILabel()
    private let valuePercentageChangePeriodLabel = UILabel()
    private let valueChangeLabel = UILabel()
    private let valueChangeNameLabel = UILabel()
    private let valueLabel = UILabel()
    private let valueNameLabel = UILabel()

    weak var delegate: SendHeaderViewDelegate?

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

        blockchainLabel.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)


        blockChainTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        blockChainTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        let titleRowStack = [titleLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15, alignment: .center)

        let bottomRowStack = [blockchainLabel, issuerLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 15)
        blockchainLabel.setContentCompressionResistancePriority(.required, for: .vertical)

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
            titleRowStack,
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

            blockchainLabel.heightAnchor.constraint(equalToConstant: Screen.TokenCard.Metric.blockChainTagHeight),

            middleBorder.heightAnchor.constraint(equalToConstant: 1),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 37),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -37),
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

        blockchainLabel.setTitleColor(viewModel.subtitleColor, for: .normal)
        blockchainLabel.titleLabel?.font = viewModel.subtitleFont
        blockchainLabel.setTitle(viewModel.blockChainName, for: .normal)

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        let issuer = viewModel.issuer
        if issuer.isEmpty {
            issuerLabel.text = ""
        } else {
            issuerLabel.text = "\(R.string.localizable.aWalletContentsIssuerTitle()): \(issuer)"
        }

        blockChainTagLabel.textAlignment = viewModel.blockChainNameTextAlignment
        blockChainTagLabel.cornerRadius = viewModel.blockChainNameCornerRadius
        blockChainTagLabel.backgroundColor = viewModel.blockChainNameBackgroundColor
        blockChainTagLabel.textColor = viewModel.blockChainNameColor
        blockChainTagLabel.font = viewModel.blockChainNameFont
        blockChainTagLabel.text = viewModel.blockChainTag

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

        if viewModel.showAlternativeAmount {
            viewsToShowOnlyIfAlternativeAmountsAreAvailable.showAll()
        } else {
            viewsToShowOnlyIfAlternativeAmountsAreAvailable.hideAll()
        }
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(inHeaderView: self)
    }
}
