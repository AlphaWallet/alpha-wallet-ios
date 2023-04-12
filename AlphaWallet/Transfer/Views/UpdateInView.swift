//
//  UpdateInView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import UIKit
import Combine

class UpdateInView: UIView {

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private lazy var timerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false

        return indicator
    }()

    private let viewModel: UpdateInViewModel
    private var cancellable = Set<AnyCancellable>()

    init(viewModel: UpdateInViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        addSubview(titleLabel)
        addSubview(timerLabel)
        addSubview(loadingIndicator)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            titleLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            timerLabel.centerXAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            timerLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: timerLabel.trailingAnchor, constant: 10),
            loadingIndicator.centerYAnchor.constraint(equalTo: timerLabel.centerYAnchor)
        ])

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: UpdateInViewModel) {
        let input = UpdateInViewModelInput()
        let output = viewModel.transform(input: input)

        output.text
            .assign(to: \.attributedText, on: titleLabel, ownership: .weak)
            .store(in: &cancellable)

        output.timerText
            .assign(to: \.attributedText, on: timerLabel, ownership: .weak)
            .store(in: &cancellable)

        output.isLoadingHidden
            .sink { [weak loadingIndicator] isLoadingHidden in
                if isLoadingHidden {
                    loadingIndicator?.stopAnimating()
                } else {
                    loadingIndicator?.startAnimating()
                }
            }.store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
