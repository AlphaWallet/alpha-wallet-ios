// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol DiscoverDappCellDelegate: class {
    func onAdd(dapp: Dapp, inCell cell: DiscoverDappCell)
    func onRemove(dapp: Dapp, inCell cell: DiscoverDappCell)
}

class DiscoverDappCell: UITableViewCell {
    static let identifier = "DiscoverDappCell"

    private let addButton = UIButton(type: .system)
    private let removeButton = UIButton(type: .system)
    private var viewModel: DiscoverDappCellViewModel?
    private var iconImageViewHolder = ContainerViewWithShadow(aroundView: UIImageView())
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    weak var delegate: DiscoverDappCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        let labelsVerticalStackView = [
            titleLabel,
            descriptionLabel
        ].asStackView(axis: .vertical)

        addButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        removeButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let mainStackView = [.spacerWidth(29), iconImageViewHolder, .spacerWidth(26), labelsVerticalStackView, .spacerWidth(26), addButton, removeButton, .spacerWidth(29)].asStackView(axis: .horizontal, alignment: .center)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            iconImageViewHolder.widthAnchor.constraint(equalToConstant: 44),
            iconImageViewHolder.widthAnchor.constraint(equalTo: iconImageViewHolder.heightAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DiscoverDappCellViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor

        addButton.addTarget(self, action: #selector(onTappedAdd), for: .touchUpInside)
        addButton.setTitle(R.string.localizable.addButtonTitle().localizedUppercase, for: .normal)
        addButton.isHidden = viewModel.isAddButtonHidden
        addButton.titleLabel?.font = viewModel.addRemoveButtonFont
        addButton.contentEdgeInsets = viewModel.addRemoveButtonContentEdgeInsets
        addButton.borderColor = viewModel.addRemoveButtonBorderColor
        addButton.borderWidth = viewModel.addRemoveButtonBorderWidth
        addButton.cornerRadius = viewModel.addRemoveButtonBorderCornerRadius

        removeButton.addTarget(self, action: #selector(onTappedRemove), for: .touchUpInside)
        removeButton.setTitle(R.string.localizable.removeButtonTitle().localizedUppercase, for: .normal)
        removeButton.isHidden = viewModel.isRemoveButtonHidden
        removeButton.titleLabel?.font = viewModel.addRemoveButtonFont
        removeButton.contentEdgeInsets = viewModel.addRemoveButtonContentEdgeInsets
        removeButton.borderColor = viewModel.addRemoveButtonBorderColor
        removeButton.borderWidth = viewModel.addRemoveButtonBorderWidth
        removeButton.cornerRadius = viewModel.addRemoveButtonBorderCornerRadius

        iconImageViewHolder.configureShadow(color: viewModel.imageViewShadowColor, offset: viewModel.imageViewShadowOffset, opacity: viewModel.imageViewShadowOpacity, radius: viewModel.imageViewShadowRadius, cornerRadius: iconImageViewHolder.frame.size.width / 2)

        let iconImageView = iconImageViewHolder.childView
        iconImageView.backgroundColor = viewModel.backgroundColor
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.kf.setImage(with: viewModel.imageUrl, placeholder: viewModel.fallbackImage)

        titleLabel.font = viewModel.nameFont
        titleLabel.textColor = viewModel.nameColor
        titleLabel.text = viewModel.name

        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.text = viewModel.description

        //TODO ugly hack to get the image view's frame. Can't figure out a good point to retrieve the correct frame otherwise
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.iconImageViewHolder.configureShadow(color: viewModel.imageViewShadowColor, offset: viewModel.imageViewShadowOffset, opacity: viewModel.imageViewShadowOpacity, radius: viewModel.imageViewShadowRadius, cornerRadius: self.iconImageViewHolder.frame.size.width / 2)
        }
    }

    @objc private func onTappedAdd() {
        guard let dapp = viewModel?.dapp else { return }
        delegate?.onAdd(dapp: dapp, inCell: self)
    }

    @objc private func onTappedRemove() {
        guard let dapp = viewModel?.dapp else { return }
        delegate?.onRemove(dapp: dapp, inCell: self)
    }
}
