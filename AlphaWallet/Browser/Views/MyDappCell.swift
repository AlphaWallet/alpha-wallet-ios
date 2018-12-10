// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit


class MyDappCell: UITableViewCell {

    static let identifier = "MyDappCell"

    private let iconImageViewHolder = UIView()
    private var viewModel: MyDappCellViewModel?

    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    let urlLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let labelsVerticalStackView = [
            titleLabel,
            urlLabel].asStackView(axis: .vertical)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageViewHolder.addSubview(iconImageView)

        let mainStackView = [.spacerWidth(29), iconImageViewHolder, .spacerWidth(26), labelsVerticalStackView, .spacerWidth(29)].asStackView(axis: .horizontal, alignment: .center)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.widthAnchor.constraint(equalTo: iconImageView.heightAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: iconImageViewHolder.leadingAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: iconImageViewHolder.trailingAnchor),
            iconImageView.topAnchor.constraint(equalTo: iconImageViewHolder.topAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: iconImageViewHolder.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: MyDappCellViewModel) {
        self.viewModel = viewModel

        titleLabel.font = viewModel.nameFont
        titleLabel.textColor = viewModel.nameColor
        titleLabel.text = viewModel.name

        urlLabel.font = viewModel.domainNameFont
        urlLabel.textColor = viewModel.domainNameColor
        urlLabel.text = viewModel.domainName

        iconImageViewHolder.layer.shadowColor = viewModel.imageViewShadowColor.cgColor
        iconImageViewHolder.layer.shadowOffset = viewModel.imageViewShadowOffset
        iconImageViewHolder.layer.shadowOpacity = viewModel.imageViewShadowOpacity
        iconImageViewHolder.layer.shadowRadius = viewModel.imageViewShadowRadius

        iconImageView.backgroundColor = viewModel.backgroundColor
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.kf.setImage(with: viewModel.imageUrl, placeholder: viewModel.fallbackImage)

        //TODO ugly hack to get the image view's frame. Can't figure out a good point to retrieve the correct frame otherwise
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.iconImageView.layer.cornerRadius = self.iconImageView.frame.size.width / 2
            self.iconImageViewHolder.layer.cornerRadius = self.iconImageViewHolder.frame.size.width / 2
            self.iconImageViewHolder.layer.shadowPath = UIBezierPath(roundedRect: self.iconImageViewHolder.bounds, cornerRadius: self.iconImageViewHolder.layer.cornerRadius).cgPath
        }
    }
}
