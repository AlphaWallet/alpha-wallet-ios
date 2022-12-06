//
//  ContainerCollectionViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.12.2021.
//

import UIKit

struct ContainerCollectionViewCellViewModel {
    var backgroundColor: UIColor = Configuration.Color.Semantic.collectionViewCellBackground
}

typealias TokenCardConfigurableView = UIView & TokenCardRowViewLayoutConfigurable
class ContainerCollectionViewCell: UICollectionViewCell {
    private let background = UIView()
    private let cellSeparators = (top: UIView(), bottom: UIView())
    private var _containerEdgeInsets: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
    private var subviewConstraints: [NSLayoutConstraint] = []
    private var subview: TokenCardConfigurableView? {
        viewContainerView.subviews.compactMap { $0 as? TokenCardConfigurableView }.first
    }

    private (set) lazy var viewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private (set) var stackViewConstraints: [NSLayoutConstraint] = []
    var containerEdgeInsets: UIEdgeInsets {
        get {
            _containerEdgeInsets
        }
        set {
            _containerEdgeInsets = newValue
            stackViewConstraints.configure(edgeInsets: newValue)
        }
    }

    static func configureSeparatorLines(layout: GridOrListLayout, _ element: ContainerCollectionViewCell) {
        switch layout {
        case .list:
            element.cellSeparators.bottom.backgroundColor = Configuration.Color.Semantic.tableViewSeparator
        case .grid:
            element.cellSeparators.bottom.backgroundColor = .clear
        }
    }

    @objc private func invalidateInnerLayout(_ notification: NSNotification) {
        guard
            let layout = notification.userInfo?["layout"] as? GridOrListLayout,
            let sender = notification.object as? UICollectionView, sender == collectionView else { return }

        ContainerCollectionViewCell.configureSeparatorLines(layout: layout, self)
        subview?.configureLayout(layout: layout)

        layoutSubviews()
    }

    func configure(viewModel: ContainerCollectionViewCellViewModel = .init()) {
        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(invalidateInnerLayout), name: .invalidateLayout, object: nil)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        NotificationCenter.default.addObserver(self, selector: #selector(invalidateInnerLayout), name: .invalidateLayout, object: nil)
        contentView.addSubview(background)

        background.translatesAutoresizingMaskIntoConstraints = false

        cellSeparators.top.translatesAutoresizingMaskIntoConstraints = false
        cellSeparators.bottom.translatesAutoresizingMaskIntoConstraints = false

        viewContainerView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(viewContainerView)

        stackViewConstraints = viewContainerView.anchorsConstraint(to: background, edgeInsets: _containerEdgeInsets)

        NSLayoutConstraint.activate([
            stackViewConstraints,
            background.anchorsConstraint(to: contentView)
        ])

        background.addSubview(cellSeparators.top)
        background.addSubview(cellSeparators.bottom)

        NSLayoutConstraint.activate(contentView.anchorsConstraint(to: self) + [
            cellSeparators.top.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.top.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.top.topAnchor.constraint(equalTo: contentView.topAnchor),
            cellSeparators.top.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight),

            cellSeparators.bottom.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.bottom.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.bottom.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cellSeparators.bottom.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight),
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
} 
