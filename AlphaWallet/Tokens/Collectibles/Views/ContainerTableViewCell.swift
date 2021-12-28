//
//  ContainerTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

///Reusable TableViewCell allows to change its contantained view
class ContainerTableViewCell: UITableViewCell {
    let background = UIView()
    let cellSeparators = (top: UIView(), bottom: UIView())

    private (set) lazy var viewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private (set) lazy var stackView = [viewContainerView].asStackView(spacing: 5, alignment: .center)
    private (set) var stackViewConstraints: [NSLayoutConstraint] = []
    private var _containerEdgeInsets: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)

    var containerEdgeInsets: UIEdgeInsets {
        get {
            _containerEdgeInsets
        }
        set {
            _containerEdgeInsets = newValue
            NSLayoutConstraint.deactivate(stackViewConstraints)

            stackViewConstraints = stackView.anchorsConstraint(to: background, edgeInsets: newValue)
            NSLayoutConstraint.activate([stackViewConstraints])
        }
    }
    private var subviewConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)

        background.translatesAutoresizingMaskIntoConstraints = false
        selectionStyle = .none

        cellSeparators.top.translatesAutoresizingMaskIntoConstraints = false
        cellSeparators.bottom.translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        stackViewConstraints = stackView.anchorsConstraint(to: background, edgeInsets: _containerEdgeInsets)

        NSLayoutConstraint.activate([
            stackViewConstraints,
            background.anchorsConstraint(to: contentView)
        ])

        background.addSubview(cellSeparators.top)
        background.addSubview(cellSeparators.bottom)

        NSLayoutConstraint.activate([
            cellSeparators.top.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.top.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.top.topAnchor.constraint(equalTo: contentView.topAnchor),
            cellSeparators.top.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),

            cellSeparators.bottom.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.bottom.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.bottom.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cellSeparators.bottom.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),
        ])
    }

    func configure(subview: UIView) {
        viewContainerView.subviews.forEach { $0.removeFromSuperview() }
        NSLayoutConstraint.deactivate(subviewConstraints)

        subview.translatesAutoresizingMaskIntoConstraints = false
        viewContainerView.addSubview(subview)
        subviewConstraints = subview.anchorsConstraint(to: viewContainerView)

        NSLayoutConstraint.activate(subviewConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}
