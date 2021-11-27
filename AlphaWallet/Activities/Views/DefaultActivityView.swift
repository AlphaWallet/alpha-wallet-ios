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
        background.backgroundColor = Colors.clear
        backgroundColor = Colors.clear
        amountLabel.attributedText = viewModel.amount
        amountLabel.textAlignment = .center
    }
}
