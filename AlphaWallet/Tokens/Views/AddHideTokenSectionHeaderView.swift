// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
extension AddHideTokensViewController {
    class functional {}
}

extension AddHideTokensViewController.functional {

    static func headerView(for section: Int, viewModel: AddHideTokenSectionHeaderViewModel) -> UIView {
        let view = AddHideTokenSectionHeaderView()
        view.configure(viewModel: viewModel)

        return view
    }
}

private class AddHideTokenSectionHeaderView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
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
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20, backgroundColor: .clear),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            bottomSperator.heightAnchor.constraint(equalToConstant: 1)
        ])

        topSeparatorHeight = topSeparator.heightAnchor.constraint(equalToConstant: 1)
        topSeparatorHeight.isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: AddHideTokenSectionHeaderViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.font = viewModel.titleTextFont

        topSeparator.backgroundColor = viewModel.separatorColor
        bottomSperator.backgroundColor = viewModel.separatorColor
        backgroundColor = viewModel.backgroundColor
        topSeparatorHeight.constant = 0
    }
}
