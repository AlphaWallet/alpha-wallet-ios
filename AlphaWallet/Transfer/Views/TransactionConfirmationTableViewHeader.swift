//
//  ConfirmationTableHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.07.2020.
//

import UIKit

protocol TransactionConfirmationTableViewHeaderDelegate: class {
    func headerView(_ header: TransactionConfirmationTableViewHeader, didSelectExpand sender: UIButton, section: Int)
}

class TransactionConfirmationTableViewHeader: UITableViewHeaderFooterView {

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
    private var viewModel: TransactionConfirmationTableViewHeaderViewModel?

    weak var delegate: TransactionConfirmationTableViewHeaderDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = R.color.mercury()

        let row0 = [
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16),
            placeholderLabel,
            [titleLabel, detailsLabel].asStackView(axis: .vertical),
            expandButton,
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16)
        ].asStackView(axis: .horizontal)

        let stackView = [
            separatorLine,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20),
            row0,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20)
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

    func configure(viewModel: TransactionConfirmationTableViewHeaderViewModel) {
        self.viewModel = viewModel

        contentView.backgroundColor = viewModel.backgroundColor
        backgroundColor = viewModel.backgroundColor

        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleLabelFont
        titleLabel.textColor = viewModel.titleLabelColor

        placeholderLabel.text = viewModel.placeholder
        placeholderLabel.font = viewModel.placeholderLabelFont
        placeholderLabel.textColor = viewModel.placeholderLabelColor

        detailsLabel.text = viewModel.details
        detailsLabel.font = viewModel.detailsLabelFont
        detailsLabel.textColor = viewModel.detailsLabelColor

        switch viewModel.expandingState {
        case .opened(_, let isOpened):
            expandButton.isSelected = isOpened
        case .closed:
             break
        }

        expandButton.isHidden = viewModel.expandingState.shouldHideExpandButton
    }

    @objc private func expandSelected(_ sender: UIButton) {
        sender.isSelected.toggle()
        guard let viewModel = viewModel else { return }

        switch viewModel.expandingState {
        case .opened(let section, _):
            delegate?.headerView(self, didSelectExpand: sender, section: section)
        case .closed:
            break
        }
    }
}
