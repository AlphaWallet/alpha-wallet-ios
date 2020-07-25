// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class AddHideTokensTableHeaderView: UITableViewHeaderFooterView {
    lazy private var addHideTokensView = ShowAddHideTokensView()

    weak var delegate: ShowAddHideTokensViewDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        addHideTokensView.delegate = self

        addHideTokensView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addHideTokensView)

        NSLayoutConstraint.activate([
            addHideTokensView.anchorsConstraint(to: contentView)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure() {
        addHideTokensView.configure(viewModel: .init())
    }
}

extension AddHideTokensTableHeaderView: ShowAddHideTokensViewDelegate {
    func view(_ view: ShowAddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.view(view, didSelectAddHideTokensButton: sender)
    }
}
