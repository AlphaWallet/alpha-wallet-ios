//
//  ConfirmTransactionTableViewHeader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.07.2020.
//

import UIKit

struct ConfirmTransactionTableViewHeaderViewModel {
    let title: String
    let placeholder: String
    var details: String = String()
    let isOpened: Bool
    let section: Int
    var shouldHideExpandButton: Bool = false

    var titleLabelFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var titleLabelColor: UIColor {
        return R.color.black()!
    }

    var placeholderLabelFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var placeholderLabelColor: UIColor {
        return R.color.dove()!
    }

    var detailsLabelFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var detailsLabelColor: UIColor {
        return R.color.dove()!
    }
}

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
        button.tintColor = R.color.mercury()

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
        contentView.backgroundColor = .white
        backgroundColor = .white

        NSLayoutConstraint.activate([
            placeholderLabel.widthAnchor.constraint(equalToConstant: 100),
            expandButton.widthAnchor.constraint(equalToConstant: 24),
            expandButton.heightAnchor.constraint(equalToConstant: 24),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            stackView.anchorsConstraint(to: contentView)
        ])

        expandButton.addTarget(self, action: #selector(expandSelected), for: .touchUpInside)
        isSelectedObservation = expandButton.observe(\.isSelected) { button, _ in
            UIView.animate(withDuration: 0.2) {
                self.titleLabel.alpha = button.isSelected ? 0.0 : 1.0
            }
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: ConfirmTransactionTableViewHeaderViewModel) {
        self.viewModel = viewModel
        
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
