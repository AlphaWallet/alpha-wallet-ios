//
//  TokenAttributeView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit 

protocol TokenAttributeViewDelegate: class {
    func didSelect(in view: TokenAttributeView)
}

class TokenAttributeView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        return label
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    weak var delegate: TokenAttributeViewDelegate?
    let indexPath: IndexPath

    init(edgeInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 0, right: 20), indexPath: IndexPath) {
        self.indexPath = indexPath
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let subStackView = [titleLabel, valueLabel].asStackView(spacing: 5)
        let stackView = [
            .spacer(height: 0, flexible: true),
            subStackView,
            .spacer(height: 0, flexible: true),
            separatorView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        subStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            subStackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            stackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
        ])

        isUserInteractionEnabled = true
        _ = UITapGestureRecognizer(addToView: self, closure: { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.didSelect(in: strongSelf)
        })
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TokenAttributeViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle
        titleLabel.isHidden = titleLabel.attributedText == nil

        valueLabel.attributedText = viewModel.attributedValue
        valueLabel.isHidden = valueLabel.attributedText == nil

        valueLabel.numberOfLines = viewModel.valueLabelNumberOfLines
        separatorView.backgroundColor = viewModel.separatorColor
        separatorView.isHidden = viewModel.isSeparatorHidden
    }
}
