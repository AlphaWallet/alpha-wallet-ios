// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class AddHideTokensCell: UITableViewCell {
    static let identifier = "AddHideTokensCell"

    lazy private var addHideTokensView = ShowAddHideTokensView()

    weak var delegate: ShowAddHideTokensViewDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        addHideTokensView.delegate = self

        addHideTokensView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addHideTokensView)

        NSLayoutConstraint.activate([
            addHideTokensView.anchorsConstraint(to: contentView),
            addHideTokensView.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        addHideTokensView.configure(viewModel: .init())
    }
}

extension AddHideTokensCell: ShowAddHideTokensViewDelegate {
    func view(_ view: ShowAddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.view(view, didSelectAddHideTokensButton: sender)
    }
}
