// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class DefaultActivityView: UIView {
    private var viewModel: DefaultActivityViewModel?
    private let background = UIView()
    private let amountLabel = UILabel()

    init() {
        super.init(frame: .zero)

        addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(amountLabel)

        NSLayoutConstraint.activate([
            amountLabel.anchorsConstraint(to: background),

            background.anchorsConstraint(to: self),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DefaultActivityViewModel) {
        self.viewModel = viewModel

        background.backgroundColor = viewModel.contentsBackgroundColor

        backgroundColor = viewModel.backgroundColor

        amountLabel.text = viewModel.amount
        amountLabel.font = viewModel.amountFont
        amountLabel.textColor = viewModel.amountColor

        amountLabel.textAlignment = .center
    }
}
