//
//  SelectableAssetTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

class SelectableAssetTableViewCell: ContainerTableViewCell {

    private var selectionStateViews: (containerView: UIView, selectionImageView: UIImageView) = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 40),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 25),
            imageView.heightAnchor.constraint(equalToConstant: 25),
        ])

        return (view, imageView)
    }()

    private let selectedAmountView: AssetSelectionCircleOverlayView = {
        let view = AssetSelectionCircleOverlayView()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        stackView.removeAllArrangedSubviews()
        stackView.addArrangedSubviews([selectionStateViews.containerView, viewContainerView])
    }

    private var selectionViewPositioningConstraints: [NSLayoutConstraint] = []

    func prapare(with view: UIView & SelectionPositioningView) {
        super.configure(subview: view)

        NSLayoutConstraint.deactivate(selectionViewPositioningConstraints)
        selectedAmountView.removeFromSuperview()

        view.positioningView.addSubview(selectedAmountView)

        selectionViewPositioningConstraints = [
            selectedAmountView.centerXAnchor.constraint(equalTo: view.positioningView.centerXAnchor),
            selectedAmountView.centerYAnchor.constraint(equalTo: view.positioningView.centerYAnchor),

            selectedAmountView.heightAnchor.constraint(equalToConstant: 35),
            selectedAmountView.widthAnchor.constraint(equalToConstant: 35)
        ]

        NSLayoutConstraint.activate(selectionViewPositioningConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: SelectableAssetContainerViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor
        contentView.backgroundColor = viewModel.contentsBackgroundColor

        selectedAmountView.configure(viewModel: viewModel.selectionViewModel)
        selectionStateViews.selectionImageView.image = viewModel.selectionImage
    }
}
