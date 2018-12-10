// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol DappViewCellDelegate: class {
    func didTapDelete(dapp: Bookmark, inCell cell: DappViewCell)
    func didLongPressed(dapp: Bookmark, onCell cell: DappViewCell)
}

//hboon because of how we implemented shadows parallex doesn't work anymore. Fix it again by adding another wrapper around imageHolder? Maybe shadow should just be implemented with a sublayer
class DappViewCell: UICollectionViewCell {
    static let identifier = "DappViewCell"

    private let marginAroundImage = CGFloat(7)
    private let jiggleAnimationKey = "jiggle"
    private var viewModel: DappViewCellViewModel?
    private var currentDisplayedImageUrl: URL?
    private let background = UIView()
    private let imageView = UIImageView()
    //Holder to show the shadow around the image because the UIImageView is clipsToBounds=true
    private let imageHolder = UIView()
    private let titleLabel = UILabel()
    private let domainLabel = UILabel()
    private let deleteButton = UIButton(type: .system)
    var isEditing: Bool = false {
        didSet {
            if isEditing {
                let randomNumber = CGFloat(arc4random_uniform(500)) / 500 + 0.5
                let angle = CGFloat(0.06 * randomNumber)
                let left = CATransform3DMakeRotation(angle, 0, 0, 1)
                let right = CATransform3DMakeRotation(-angle, 0, 0, 1)
                let animation = CAKeyframeAnimation(keyPath: "transform")
                animation.values = [left, right]
                animation.autoreverses = true
                animation.duration = 0.125
                animation.repeatCount = Float(Int.max)
                contentView.layer.add(animation, forKey: jiggleAnimationKey)
            } else {
                contentView.layer.removeAnimation(forKey: jiggleAnimationKey)
            }
            deleteButton.isHidden = !isEditing
        }
    }
    weak var delegate: DappViewCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.addSubview(imageView)

        let stackView = [
            .spacer(height: marginAroundImage),
            imageHolder,
            .spacer(height: 9),
            titleLabel,
            domainLabel,
        ].asStackView(axis: .vertical, spacing: 0, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        deleteButton.addTarget(self, action: #selector(deleteDapp), for: .touchUpInside)
        deleteButton.isHidden = true
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(deleteButton)

        let xMargin = CGFloat(0)
        let yMargin = CGFloat(0)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -yMargin),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: background.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor),

            imageHolder.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: marginAroundImage),
            imageHolder.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -marginAroundImage),
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            imageView.leadingAnchor.constraint(equalTo: imageHolder.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageHolder.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: imageHolder.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageHolder.bottomAnchor),

            deleteButton.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            //Some allowance so the delete button is not clipped while jiggling
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.widthAnchor.constraint(equalTo: deleteButton.heightAnchor),
        ])

        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressedDappCell)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        imageHolder.layer.cornerRadius = imageHolder.frame.size.width / 2
        imageView.layer.cornerRadius = imageView.frame.size.width / 2

        imageHolder.layer.shadowPath = UIBezierPath(roundedRect: imageHolder.bounds, cornerRadius: imageHolder.layer.cornerRadius).cgPath
    }

    func configure(viewModel: DappViewCellViewModel) {
        self.viewModel = viewModel

        contentView.backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.backgroundColor
        background.clipsToBounds = true

        imageHolder.layer.shadowColor = viewModel.imageViewShadowColor.cgColor
        imageHolder.layer.shadowOffset = viewModel.imageViewShadowOffset
        imageHolder.layer.shadowOpacity = viewModel.imageViewShadowOpacity
        imageHolder.layer.shadowRadius = viewModel.imageViewShadowRadius

        imageView.backgroundColor = viewModel.backgroundColor
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.kf.setImage(with: viewModel.imageUrl, placeholder: viewModel.fallbackImage)

        deleteButton.tintColor = Colors.appRed
        deleteButton.imageView?.tintColor = Colors.appRed
        deleteButton.setImage(R.image.onboarding_failed(), for: .normal)

        titleLabel.textAlignment = .center
        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title

        domainLabel.textAlignment = .center
        domainLabel.textColor = viewModel.domainNameColor
        domainLabel.font = viewModel.domainNameFont
        domainLabel.text = viewModel.domainName
    }

    @objc func deleteDapp() {
        guard let dapp = viewModel?.dapp else { return }
        delegate?.didTapDelete(dapp: dapp, inCell: self)
    }

    @objc private func longPressedDappCell() {
        guard let dapp = viewModel?.dapp else { return }
        delegate?.didLongPressed(dapp: dapp, onCell: self)
    }
}
