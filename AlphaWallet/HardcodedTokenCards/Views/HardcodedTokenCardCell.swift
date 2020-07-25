// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import UIKit

class HardcodedTokenCardCell: UITableViewCell {
    private let labelLabel = UILabel()
    private let valueLabel = UILabel()
    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.layer.masksToBounds = true
        progressView.layer.cornerRadius = 4
        progressView.tintColor = Colors.appTint
        progressView.trackTintColor = .init(red: 216, green: 216, blue: 216)
        return progressView
    }()
    lazy private var progressViewBoxView: UIView = BoxView(view: progressView, insets: UIEdgeInsets(top: 0, left: 16, bottom: 20, right: 16))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let row0 = [.spacerWidth(16), labelLabel, .spacerWidth(7), valueLabel, .spacerWidth(16)].asStackView(axis: .horizontal)

        let stackView = [
            row0,
            progressViewBoxView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            progressView.heightAnchor.constraint(equalToConstant: 8),

            stackView.anchorsConstraint(to: self),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: HardcodedTokenCardCellViewModel) {
        separatorInset = .zero
        layoutMargins = .zero

        labelLabel.textColor = viewModel.labelColor
        labelLabel.font = viewModel.labelFont
        labelLabel.text = viewModel.title

        valueLabel.textColor = viewModel.valueColor
        valueLabel.font = viewModel.valueFont
        valueLabel.textAlignment = .right
        valueLabel.text = viewModel.value

        if let progress = viewModel.progressValue {
            progressView.progress = progress
            progressViewBoxView.isHidden = false
        } else {
            progressViewBoxView.isHidden = true
        }
    }
}

