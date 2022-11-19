// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol BrowserHistoryHeaderViewDelegate: AnyObject {
    func didTapClearAll(in headerView: BrowserHistoryHeaderView)
}

class BrowserHistoryHeaderView: UIView {
    private let header = BrowserHomeHeaderView()
    private let clearButton = UIButton(type: .system)

    weak var delegate: BrowserHistoryHeaderViewDelegate?

    init() {
        super.init(frame: .zero)

        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        clearButton.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            header.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -30),

            clearButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            clearButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])

        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BrowserHomeHeaderViewModel) {
        header.configure(viewModel: viewModel)

        clearButton.setTitle(R.string.localizable.clearButtonTitle().localizedUppercase, for: .normal)
        clearButton.titleLabel?.font = Fonts.bold(size: 12)
    }

    @objc private func clearHistory() {
        delegate?.didTapClearAll(in: self)
    }
}
