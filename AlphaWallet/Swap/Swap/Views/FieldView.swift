//
//  FieldView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

final class FieldView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    private var cancelable = Set<AnyCancellable>()

    init(edgeInsets: UIEdgeInsets) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints =  false

        let stackview = [titleLabel, .spacerWidth(flexible: true), valueLabel].asStackView()
        stackview.translatesAutoresizingMaskIntoConstraints =  false

        addSubview(stackview)

        NSLayoutConstraint.activate([
            stackview.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            titleLabel.leadingAnchor.constraint(equalTo: stackview.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: stackview.trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    } 

    func bind(viewModel: FieldViewModel) {
        titleLabel.attributedText = viewModel.titleAttributedString
        backgroundColor = viewModel.backgroundColor
        viewModel.valueAttributedString
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak valueLabel] attributedText in
                valueLabel?.attributedText = attributedText
            }).store(in: &cancelable)
    }
}
