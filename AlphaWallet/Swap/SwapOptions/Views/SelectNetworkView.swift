//
//  SelectNetworkView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit 

class SelectNetworkView: HighlightableView {

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    let subTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    let networkImageView: ImageView = {
        let imageView = ImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        return imageView
    }()

    let selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var actionButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()

    private let separatorLine: UIView = {
        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false

        return separatorLine
    }()

    init(edgeInsets: UIEdgeInsets) {
        super.init()
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        
        let leftStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let rightStackView = [
            selectionImageView
        ].asStackView(axis: .vertical, alignment: .trailing)

        let cell = [
            .spacerWidth(edgeInsets.left),
            networkImageView,
            .spacerWidth(15),
            leftStackView,
            .spacerWidth(15),
            rightStackView,
            .spacerWidth(edgeInsets.right),
        ].asStackView(axis: .horizontal, alignment: .center)

        let stackView = [
            .spacer(height: edgeInsets.top),
            cell,
            .spacer(height: edgeInsets.bottom)
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        addSubview(unavailableToSelectView)
        
        NSLayoutConstraint.activate([
            networkImageView.heightAnchor.constraint(equalToConstant: 40),
            networkImageView.widthAnchor.constraint(equalToConstant: 40),

            selectionImageView.heightAnchor.constraint(equalToConstant: 30),
            selectionImageView.widthAnchor.constraint(equalToConstant: 30),

            stackView.anchorsConstraint(to: self),
            unavailableToSelectView.anchorsConstraint(to: self)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private lazy var unavailableToSelectView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white.withAlphaComponent(0.4)
        view.isHidden = false

        return view
    }()

    func configure(viewModel: SelectNetworkViewModel) {
        titleLabel.attributedText = viewModel.titleAttributedString
        subTitleLabel.attributedText = viewModel.subTitleAttributedString
        networkImageView.subscribable = viewModel.networkImage
        selectionImageView.image = viewModel.selectionImage
        set(backgroundColor: viewModel.highlightedBackgroundColor, forState: .highlighted)
        set(backgroundColor: viewModel.normalBackgroundColor, forState: .normal)
        unavailableToSelectView.isHidden = viewModel.isAvailableToSelect
        isUserInteractionEnabled = viewModel.isAvailableToSelect
    }
}
