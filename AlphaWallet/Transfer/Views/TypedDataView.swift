//
//  TypedDataView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2021.
//

import UIKit

protocol TypedDataViewDelegate: AnyObject {
    func copySelected(in view: TypedDataView)
}

class TypedDataView: UIView {

    private lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var valueLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let copyButton: UIButton = {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setImage(R.image.copy(), for: .normal)
        return view
    }()

    weak var delegate: TypedDataViewDelegate?

    init() {
        super.init(frame: .zero)

        let stackView = [
            titleLabel,
            valueLabel
        ].asStackView(axis: .vertical, alignment: .fill)

        addSubview(stackView)
        addSubview(copyButton)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -5),

            copyButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
        ])

        copyButton.addTarget(self, action: #selector(copySelected), for: .touchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func copySelected(_ sender: UIButton) {
        delegate?.copySelected(in: self)
    }

    func configure(viewModel: TypedDataViewModel) {
        backgroundColor = viewModel.backgroundColor
        copyButton.isHidden = viewModel.isCopyHidden
        titleLabel.attributedText = viewModel.nameAttributeString
        valueLabel.attributedText = viewModel.valueAttributeString
    }
}
