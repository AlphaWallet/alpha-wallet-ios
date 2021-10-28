//
//  ContainerCollectionViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.12.2021.
//

import UIKit

typealias TokenCardConfigurableView = TokenCardRowViewProtocol & UIView & TokenCardRowViewLayoutConfigurableProtocol
class TokenCardContainerCollectionViewCell: ContainerCollectionViewCell {
    weak var delegate: BaseTokenCardTableViewCellDelegate?

    var subview: TokenCardConfigurableView? {
        viewContainerView.subviews.compactMap { $0 as? TokenCardConfigurableView }.first
    }
    var anyObject: AnyObject?

    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(invalidateInnerLayout), name: .invalidateLayout, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(invalidateInnerLayout), name: .invalidateLayout, object: nil)
    }

    static func configureSeparatorLines(selection: GridOrListSelectionState, _ element: TokenCardContainerCollectionViewCell) {
        switch selection {
        case .list:
            element.cellSeparators.bottom.backgroundColor = R.color.mercury()
        case .grid:
            element.cellSeparators.bottom.backgroundColor = .clear
        }
    }

    @objc private func invalidateInnerLayout(_ notification: NSNotification) {
        guard
            let selection = notification.userInfo?["selection"] as? GridOrListSelectionState,
            let sender = notification.object as? UICollectionView, sender == collectionView else { return }

        TokenCardContainerCollectionViewCell.configureSeparatorLines(selection: selection, self)
        subview?.configureLayout(layout: selection)

        layoutSubviews()
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel, tokenId: TokenId, assetDefinitionStore: AssetDefinitionStore) {
        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor

        subview?.configure(tokenHolder: viewModel.tokenHolder, tokenId: tokenId, tokenView: viewModel.tokenView, areDetailsVisible: viewModel.areDetailsVisible, width: viewModel.cellWidth, assetDefinitionStore: assetDefinitionStore)
    }
}

extension TokenCardContainerCollectionViewCell: OpenSeaNonFungibleTokenCardRowViewDelegate {
    func didTapURL(url: URL) {
        delegate?.didTapURL(url: url)
    }
}

///Reusable TableViewCell allows to change its contantained view
class ContainerCollectionViewCell: UICollectionViewCell {
    let background = UIView()
    let cellSeparators = (top: UIView(), bottom: UIView())

    private (set) lazy var viewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private (set) var stackViewConstraints: [NSLayoutConstraint] = []
    private var _containerEdgeInsets: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)

    var containerEdgeInsets: UIEdgeInsets {
        get {
            _containerEdgeInsets
        }
        set {
            _containerEdgeInsets = newValue
            stackViewConstraints.configure(edgeInsets: newValue)
        }
    }
    private var subviewConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

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
