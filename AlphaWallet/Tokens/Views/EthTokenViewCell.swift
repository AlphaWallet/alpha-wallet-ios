// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class EthTokenViewCell: UITableViewCell {
    static let identifier = "EthTokenViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()
    private let valuePercentageChangeValueLabel = UILabel()
    private let valuePercentageChangePeriodLabel = UILabel()
    private let valueChangeLabel = UILabel()
    private let valueLabel = UILabel()
    private let blockchainLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [titleLabel, valuePercentageChangeValueLabel, valuePercentageChangePeriodLabel, valueChangeLabel]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false
        valuePercentageChangeValueLabel.textAlignment = .center
        valuePercentageChangePeriodLabel.textAlignment = .center
        valueChangeLabel.textAlignment = .center
        valueLabel.textAlignment = .center

        let stackView = [
            titleLabel,
            [blockchainLabel, valueLabel, UIView.spacerWidth(flexible: true), valueChangeLabel, valuePercentageChangeValueLabel].asStackView(spacing: 5)
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.anchorsConstraint(to: contentView)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: EthTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor

        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = "\(viewModel.amount) \(viewModel.title)"
        titleLabel.baselineAdjustment = .alignCenters 

        valuePercentageChangeValueLabel.textColor = viewModel.valuePercentageChangeColor
        valuePercentageChangeValueLabel.font = viewModel.textValueFont
        valuePercentageChangeValueLabel.text = viewModel.valuePercentageChangeValue

        valueChangeLabel.textColor = viewModel.textColor
        valueChangeLabel.font = viewModel.textValueFont
        valueChangeLabel.text = viewModel.valueChange

        valueLabel.textColor = viewModel.textColor
        valueLabel.font = viewModel.textValueFont
        valueLabel.text = viewModel.value

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName
        blockchainLabel.isHidden = viewModel.blockChainLabelHidden
        
        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
    }
}
