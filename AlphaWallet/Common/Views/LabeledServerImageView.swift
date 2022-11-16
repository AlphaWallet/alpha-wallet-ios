//
//  LabeledServerImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.11.2022.
//

import UIKit

class LabeledServerImageView: UIView {
    private let serverImageView: RoundedImageView = {
        let iconView = RoundedImageView(size: DataEntry.Metric.ImageView.serverIconSize)
        return iconView
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 17)
        label.numberOfLines = 0

        return label
    }()
    private lazy var stackView: UIStackView = [serverImageView, label].asStackView(spacing: 5)

    init(viewModel: LabeledServerImageViewModel) {
        super.init(frame: .zero)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 5, left: 0, bottom: 5, right: 0))
        ])

        configure(viewModel: viewModel)
    }

    func configure(viewModel: LabeledServerImageViewModel) {
        switch viewModel.layout {
        case .horizontal:
            stackView.axis = .horizontal
            stackView.alignment = .fill
        case .vertical:
            stackView.axis = .vertical
            stackView.alignment = .center
        }

        label.text = viewModel.server.name
        serverImageView.subscribable = viewModel.server.walletConnectIconImage
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
