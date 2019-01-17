// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappsHomeEmptyView: UIView {
    private let header = DappsHomeHeaderView()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)

        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 50),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappsHomeEmptyViewViewModel) {
        backgroundColor = viewModel.headerViewViewModel.backgroundColor
        header.configure(viewModel: viewModel.headerViewViewModel)

        label.font = Fonts.light(size: 18)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = viewModel.title
    }
}
