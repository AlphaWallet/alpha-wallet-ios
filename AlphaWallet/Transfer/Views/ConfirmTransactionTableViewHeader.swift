//
//  ConfirmTransactionTableViewHeader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.07.2020.
//

import UIKit

protocol ConfirmTransactionTableViewHeaderDelegate: class {
    func headerView(_ header: ConfirmTransactionTableViewHeader, didSelectExpand sender: UIButton, section: Int)
}

class ConfirmTransactionTableViewHeader: UITableViewHeaderFooterView {

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let expandButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.expand()?.withRenderingMode(.alwaysTemplate), for: .selected)
        button.setImage(R.image.not_expand()?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = R.color.black()

        return button
    }()
    private var isSelectedObservation: NSKeyValueObservation!
    private var viewModel: ConfirmTransactionTableViewHeaderViewModel?

    weak var delegate: ConfirmTransactionTableViewHeaderDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = R.color.mercury()

        let row0 = [
            .spacerWidth(16),
            placeholderLabel,
            [titleLabel, detailsLabel].asStackView(axis: .vertical),
            expandButton,
            .spacerWidth(16)
        ].asStackView(axis: .horizontal)

        let stackView = [
            separatorLine,
            .spacer(height: 20),
            row0,
            .spacer(height: 20)
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            placeholderLabel.widthAnchor.constraint(equalToConstant: 100),
            expandButton.widthAnchor.constraint(equalToConstant: 24),
            expandButton.heightAnchor.constraint(equalToConstant: 24),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            stackView.anchorsConstraint(to: contentView)
        ])

        expandButton.addTarget(self, action: #selector(expandSelected), for: .touchUpInside)
        isSelectedObservation = expandButton.observe(\.isSelected) { button, _ in
            self.titleLabel.alpha = button.isSelected ? 0.0 : 1.0
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: ConfirmTransactionTableViewHeaderViewModel) {
        self.viewModel = viewModel

        contentView.backgroundColor = viewModel.backgoundColor
        backgroundColor = viewModel.backgoundColor
        
        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleLabelFont
        titleLabel.textColor = viewModel.titleLabelColor

        placeholderLabel.text = viewModel.placeholder
        placeholderLabel.font = viewModel.placeholderLabelFont
        placeholderLabel.textColor = viewModel.placeholderLabelColor

        detailsLabel.text = viewModel.details
        detailsLabel.font = viewModel.detailsLabelFont
        detailsLabel.textColor = viewModel.detailsLabelColor

        expandButton.isHidden = viewModel.shouldHideExpandButton
        expandButton.isSelected = viewModel.isOpened
    }

    @objc private func expandSelected(_ sender: UIButton) {
        sender.isSelected.toggle()
        guard let viewModel = viewModel else { return }

        delegate?.headerView(self, didSelectExpand: sender, section: viewModel.section)
    }
} 
