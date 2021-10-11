//
//  SettingViewHeader.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 08/04/20.
//

import UIKit

class SettingViewHeader: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    }()

    private let topSeparator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()

    private let bottomSperator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()

    private var topSeparatorHeight: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)

        let stackView = [
            topSeparator,
            .spacer(height: 13, backgroundColor: .clear),
            [.spacerWidth(16), titleLabel, detailsLabel, .spacerWidth(16)].asStackView(axis: .horizontal, alignment: .center),
            .spacer(height: 13, backgroundColor: .clear),
            bottomSperator
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        topSeparatorHeight = topSeparator.heightAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            bottomSperator.heightAnchor.constraint(equalToConstant: 1),
            topSeparatorHeight
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SettingViewHeaderViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.font = viewModel.titleTextFont

        detailsLabel.text = viewModel.detailsText
        detailsLabel.textColor = viewModel.detailsTextColor
        detailsLabel.font = viewModel.detailsTextFont
        topSeparator.backgroundColor = viewModel.separatorColor
        bottomSperator.backgroundColor = viewModel.separatorColor
        backgroundColor = viewModel.backgroundColor
        topSeparatorHeight.constant = viewModel.showTopSeparator ? 1 : 0
    }
}
