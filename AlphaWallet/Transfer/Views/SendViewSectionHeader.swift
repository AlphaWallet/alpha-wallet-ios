//
//  SendViewSectionHeader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit

class SendViewSectionHeader: UIView {

    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        return label
    }()

    private let topSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var topSeparatorLineHeight: NSLayoutConstraint!
    private var bottomSeparatorLineHeight: NSLayoutConstraint!
    private let separatorHeight: CGFloat = 1

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            topSeparatorView,
            [.spacerWidth(16), textLabel, .spacerWidth(16)].asStackView(),
            bottomSeparatorView
        ].asStackView(axis: .vertical, spacing: 13)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        //NOTE: we want heigh to be 50 points, with setting textLabel.heightAnchor 22 we satisfy it
        topSeparatorLineHeight = topSeparatorView.heightAnchor.constraint(equalToConstant: separatorHeight)
        bottomSeparatorLineHeight = bottomSeparatorView.heightAnchor.constraint(equalToConstant: separatorHeight)
        NSLayoutConstraint.activate([
            bottomSeparatorLineHeight,
            topSeparatorLineHeight,
            textLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            stackView.anchorsConstraint(to: self)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: SendViewSectionHeaderViewModel) {
        textLabel.text = viewModel.text
        textLabel.textColor = viewModel.textColor
        textLabel.font = viewModel.font
        backgroundColor = viewModel.backgroundColor
        topSeparatorView.backgroundColor = viewModel.separatorBackgroundColor
        bottomSeparatorView.backgroundColor = viewModel.separatorBackgroundColor
        topSeparatorLineHeight.constant = viewModel.showTopSeparatorLine ? separatorHeight : 0
        bottomSeparatorLineHeight.constant = viewModel.showBottomSeparatorLine ? separatorHeight : 0
    }
}
