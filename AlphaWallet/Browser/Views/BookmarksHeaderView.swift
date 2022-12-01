// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol BookmarksHeaderViewDelegate: AnyObject {
    func didEnterEditMode(inHeaderView headerView: BookmarksHeaderView)
    func didExitEditMode(inHeaderView headerView: BookmarksHeaderView)
}

class BookmarksHeaderView: UIView {
    private let header = BrowserHomeHeaderView()
    private let toggleEditModeButton = UIButton(type: .system)
    private var isEditing = false {
        didSet {
            if isEditing {
                configure(viewModel: .init(title: viewModel?.title ?? ""))
                delegate?.didEnterEditMode(inHeaderView: self)
            } else {
                configure(viewModel: .init(title: viewModel?.title ?? ""))
                delegate?.didExitEditMode(inHeaderView: self)
            }
        }
    }
    private var viewModel: BrowserHomeHeaderViewModel?

    weak var delegate: BookmarksHeaderViewDelegate?

    init() {
        super.init(frame: .zero)

        addSubview(header)

        toggleEditModeButton.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        toggleEditModeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toggleEditModeButton)

        NSLayoutConstraint.activate([
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            header.bottomAnchor.constraint(equalTo: toggleEditModeButton.topAnchor, constant: -30),

            toggleEditModeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            toggleEditModeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])

        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BrowserHomeHeaderViewModel) {
        self.viewModel = viewModel

        header.configure(viewModel: viewModel)

        if isEditing {
            toggleEditModeButton.setTitle(R.string.localizable.done().localizedUppercase, for: .normal)
        } else {
            toggleEditModeButton.setTitle(R.string.localizable.editButtonTitle().localizedUppercase, for: .normal)
        }
        toggleEditModeButton.titleLabel?.font = Fonts.bold(size: 12)
    }

    @objc private func toggleEditMode() {
        isEditing = !isEditing
    }

    func exitEditMode() {
        isEditing = false
    }
}
