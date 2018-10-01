// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol CryptoKittyCardRowViewDelegate: class {
    func didTapURL(url: URL)
}

class CryptoKittyCardRowView: UIView {
    let checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
    weak var delegate: CryptoKittyCardRowViewDelegate?
    let background = UIView()
    private let mainVerticalStackView: UIStackView = [].asStackView(axis: .vertical, contentHuggingPriority: .required)
    let stateLabel = UILabel()
    private let thumbnailImageView = UIImageView()
    private let bigImageBackground = UIView()
    private let bigImageView = UIImageView()
    //the SVG from CryptoKitty usually has lots of white space around the kitty. We add a container around the image view and let it bleed out a little
    private let bigImageHolder = UIView()
    private let titleLabel = UILabel()
    private let spacers = (
            aboveTitle: UIView.spacer(height: 20),
            atTop: UIView.spacer(height: 20),
            belowDescription: UIView.spacer(height: 20),
            belowState: UIView.spacer(height: 10),
            aboveHorizontalSubtitleStackView: UIView.spacer(height: 20),
            belowHorizontalSubtitleStackView: UIView.spacer(height: 20)
    )
    private let horizontalSubtitleStackView: UIStackView = [].asStackView(alignment: .center)
    private let verticalSubtitleStackView: UIStackView = [].asStackView(axis: .vertical, alignment: .leading)
    private let verticalGenerationIconImageView = UIImageView()
    private let verticalCooldownIconImageView = UIImageView()
    private let verticalGenerationLabel = UILabel()
    private let verticalCooldownLabel = UILabel()
    private let kittyIdIconLabel = UILabel()
    private let generationIconImageView = UIImageView()
    private let cooldownIconImageView = UIImageView()
    private let kittyIdLabel = UILabel()
    private let generationLabel = UILabel()
    private let cooldownLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let attributesLabel = UILabel()
    private let attributesCollectionView = { () -> UICollectionView in
        let layout = UICollectionViewFlowLayout()
        //3-column for iPhone 6s and above, 2-column for iPhone 5
        layout.itemSize = CGSize(width: 105, height: 30)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 00
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    lazy private var attributesCollectionViewHeightConstraint = attributesCollectionView.heightAnchor.constraint(equalToConstant: 100)
    private let urlButton = UIButton(type: .system)
    private let urlButtonHolder = [].asStackView(axis: .vertical, alignment: .leading)
    private let showCheckbox: Bool
    private var viewModel: CryptoKittyCardRowViewModel?
    private var thumbnailRelatedConstraints = [NSLayoutConstraint]()
    private var bigImageRelatedConstraints = [NSLayoutConstraint]()
    private var viewsVisibleWhenDetailsAreVisibleImagesAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreNotVisibleImagesAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreVisibleImagesNotAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable = [UIView]()
    private var currentDisplayedImageUrl: URL?

    init(showCheckbox: Bool = false) {
        self.showCheckbox = showCheckbox
        
        super.init(frame: .zero)

        if showCheckbox {
            addSubview(checkboxImageView)
        }

        bigImageView.translatesAutoresizingMaskIntoConstraints = false
        bigImageHolder.addSubview(bigImageView)
        bigImageHolder.isHidden = true
        bigImageBackground.isHidden = true

        urlButtonHolder.isHidden = true
        urlButton.addTarget(self, action: #selector(tappedUrl), for: .touchUpInside)

        attributesCollectionView.register(CryptoKittyCAttributeCell.self, forCellWithReuseIdentifier: CryptoKittyCAttributeCell.identifier)
        attributesCollectionView.isUserInteractionEnabled = false
        attributesCollectionView.dataSource = self

        setupLayout()
    }

    private func setupLayout() {
        addSubview(background)

        checkboxImageView.translatesAutoresizingMaskIntoConstraints = false

        background.translatesAutoresizingMaskIntoConstraints = false

        bigImageBackground.translatesAutoresizingMaskIntoConstraints = false
        bigImageBackground.layer.cornerRadius = 20
        background.addSubview(bigImageBackground)

        horizontalSubtitleStackView.addArrangedSubviews([kittyIdIconLabel, .spacerWidth(3), kittyIdLabel, .spacerWidth(7), generationIconImageView, generationLabel, .spacerWidth(7), cooldownIconImageView, cooldownLabel])

        let generationStackView = [verticalGenerationIconImageView, verticalGenerationLabel].asStackView(spacing: 0, contentHuggingPriority: .required)
        let cooldownStackView = [verticalCooldownIconImageView, verticalCooldownLabel].asStackView(spacing: 0, contentHuggingPriority: .required)
        verticalSubtitleStackView.addArrangedSubviews([
            generationStackView,
            cooldownStackView
        ])

        let col0 = [
            spacers.aboveTitle,
            stateLabel,
            spacers.belowState,
            spacers.aboveHorizontalSubtitleStackView,
            horizontalSubtitleStackView,
            spacers.belowHorizontalSubtitleStackView,
            titleLabel,
            .spacer(height: 10),
            verticalSubtitleStackView,
            descriptionLabel,
            spacers.belowDescription,
            attributesLabel,
            .spacer(height: 20),
            attributesCollectionView,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required, alignment: .leading)

        let col1 = thumbnailImageView

        let bodyStackView = [col0, col1].asStackView(axis: .horizontal, contentHuggingPriority: .required, alignment: .top)

        urlButtonHolder.addArrangedSubviews([
            .spacer(height: 20),
            urlButton,
            .spacer(height: 16),
        ])

        mainVerticalStackView.addArrangedSubviews([
            spacers.atTop,
            bigImageHolder,
            bodyStackView,
            urlButtonHolder,
        ])
        mainVerticalStackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(mainVerticalStackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin = CGFloat(7)
        let yMargin = CGFloat(5)
        var checkboxRelatedConstraints = [NSLayoutConstraint]()
        if showCheckbox {
            checkboxRelatedConstraints.append(checkboxImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
            checkboxRelatedConstraints.append(checkboxImageView.centerYAnchor.constraint(equalTo: centerYAnchor))
            checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: xMargin))
            if ScreenChecker().isNarrowScreen() {
                checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 20))
                checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 20))
            } else {
                //Have to be hardcoded and not rely on the image's size because different string lengths for the text fields can force the checkbox to shrink
                checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 28))
                checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 28))
            }
        } else {
            checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
        }

        thumbnailRelatedConstraints = [
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 150),
            thumbnailImageView.widthAnchor.constraint(equalTo: thumbnailImageView.heightAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: col0.heightAnchor),
        ]

        let marginForBigImageView = CGFloat(1)
        bigImageRelatedConstraints = [
            bigImageHolder.widthAnchor.constraint(equalTo: mainVerticalStackView.widthAnchor),
            bigImageHolder.heightAnchor.constraint(equalToConstant: 300),
            bigImageBackground.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: marginForBigImageView),
            bigImageBackground.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -marginForBigImageView),
            bigImageBackground.topAnchor.constraint(equalTo: background.topAnchor, constant: marginForBigImageView),
            bigImageBackground.bottomAnchor.constraint(equalTo: bigImageHolder.bottomAnchor, constant: 10),
        ]

        //We let the big image bleed out of its container view because CryptoKitty images has a huge empty marge around the kitties. Careful that this also fits iPhone 5s
        let bleedForBigImage: CGFloat
        if ScreenChecker().isNarrowScreen() {
            bleedForBigImage = 24
        } else {
            bleedForBigImage = 34
        }
        NSLayoutConstraint.activate([
            mainVerticalStackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            mainVerticalStackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            mainVerticalStackView.topAnchor.constraint(equalTo: background.topAnchor, constant: marginForBigImageView),
            mainVerticalStackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: 0),

            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),

            stateLabel.heightAnchor.constraint(equalToConstant: 22),

            //It is important to anchor the collection view to the outermost stackview (which has aligment=.fill) instead of child stackviews which does not have alignment=.fill
            attributesCollectionView.leadingAnchor.constraint(equalTo: mainVerticalStackView.leadingAnchor),
            attributesCollectionView.trailingAnchor.constraint(equalTo: mainVerticalStackView.trailingAnchor),
            attributesCollectionViewHeightConstraint,

            descriptionLabel.widthAnchor.constraint(equalTo: col0.widthAnchor),

            bigImageView.topAnchor.constraint(equalTo: bigImageHolder.topAnchor, constant: -bleedForBigImage),
            bigImageView.bottomAnchor.constraint(equalTo: bigImageHolder.bottomAnchor, constant: bleedForBigImage),
            bigImageView.leadingAnchor.constraint(equalTo: bigImageHolder.leadingAnchor, constant: -bleedForBigImage),
            bigImageView.trailingAnchor.constraint(equalTo: bigImageHolder.trailingAnchor, constant: bleedForBigImage),
        ] + checkboxRelatedConstraints + thumbnailRelatedConstraints)

        viewsVisibleWhenDetailsAreNotVisibleImagesAvailable = [
            spacers.aboveTitle,
            verticalSubtitleStackView,
            thumbnailImageView,
        ]

        viewsVisibleWhenDetailsAreVisibleImagesAvailable = [
            attributesLabel,
            attributesCollectionView,
            urlButtonHolder,
            bigImageHolder,
            bigImageBackground,
            horizontalSubtitleStackView,
            spacers.aboveHorizontalSubtitleStackView,
            spacers.belowHorizontalSubtitleStackView,
            spacers.belowDescription,
            descriptionLabel,
        ]
        viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable = [
            spacers.atTop,
            spacers.belowState,
        ]
        viewsVisibleWhenDetailsAreVisibleImagesNotAvailable = [
            spacers.atTop,
            spacers.belowState,
            urlButtonHolder,
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tappedUrl() {
        guard let url = viewModel?.externalLink else { return }
        delegate?.didTapURL(url: url)
    }

    func configure(viewModel: CryptoKittyCardRowViewModel) {
        self.viewModel = viewModel

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20
        background.layer.shadowRadius = 3
        background.layer.shadowColor = UIColor.black.cgColor
        background.layer.shadowOffset = CGSize(width: 0, height: 0)
        background.layer.shadowOpacity = 0.14
        background.layer.borderColor = UIColor.black.cgColor

        stateLabel.layer.cornerRadius = 10
        stateLabel.clipsToBounds = true
        stateLabel.textColor = viewModel.stateColor
        stateLabel.font = viewModel.stateFont

        kittyIdIconLabel.text = viewModel.kittyIdIconText
        kittyIdIconLabel.textColor = viewModel.kittyIdIconTextColor
        generationIconImageView.image = viewModel.generationIcon
        cooldownIconImageView.image = viewModel.cooldownIcon
        verticalGenerationIconImageView.image = viewModel.generationIcon
        verticalCooldownIconImageView.image = viewModel.cooldownIcon

        kittyIdLabel.textColor = viewModel.kittyIdTextColor
        generationLabel.textColor = viewModel.generationTextColor
        cooldownLabel.textColor = viewModel.cooldownTextColor
        kittyIdLabel.font = viewModel.subtitleFont
        generationLabel.font = viewModel.subtitleFont
        cooldownLabel.font = viewModel.subtitleFont

        verticalGenerationLabel.textColor = viewModel.generationTextColor
        verticalCooldownLabel.textColor = viewModel.cooldownTextColor
        verticalGenerationLabel.font = viewModel.subtitleFont
        verticalCooldownLabel.font = viewModel.subtitleFont

        kittyIdLabel.text = viewModel.tokenId
        generationLabel.text = viewModel.generation
        cooldownLabel.text = viewModel.cooldown
        verticalGenerationLabel.text = viewModel.generation
        verticalCooldownLabel.text = viewModel.cooldown

        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = viewModel.titleColor
        descriptionLabel.font = viewModel.descriptionFont

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont

        attributesLabel.textColor = viewModel.titleColor
        attributesLabel.font = viewModel.attributesTitleFont

        thumbnailImageView.backgroundColor = .clear

        bigImageBackground.backgroundColor = viewModel.bigImageBackgroundColor
        bigImageView.backgroundColor = .clear
        bigImageHolder.backgroundColor = .clear

        descriptionLabel.text = viewModel.description

        titleLabel.text = viewModel.title

        attributesLabel.text = viewModel.attributesTitle

        if !viewModel.areImagesHidden {
            if let currentDisplayedImageUrl = currentDisplayedImageUrl, currentDisplayedImageUrl == viewModel.imageUrl {
                //Empty
            } else {
                thumbnailImageView.image = nil
                bigImageView.image = nil
            }
            if let bigImagePromise = viewModel.bigImage {
                currentDisplayedImageUrl = viewModel.imageUrl
                bigImagePromise.done { [weak self] image in
                    guard let strongSelf = self else { return }
                    guard strongSelf.currentDisplayedImageUrl == viewModel.imageUrl else { return }
                    strongSelf.bigImageView.image = image
                    strongSelf.thumbnailImageView.image = image
                }.cauterize()
            }
        }

        viewsVisibleWhenDetailsAreVisibleImagesAvailable.forEach { $0.isHidden = true }
        viewsVisibleWhenDetailsAreVisibleImagesNotAvailable.forEach { $0.isHidden = true }
        viewsVisibleWhenDetailsAreNotVisibleImagesAvailable.forEach { $0.isHidden = true }
        viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable.forEach { $0.isHidden = true }
        if viewModel.areDetailsVisible && !viewModel.areImagesHidden {
            viewsVisibleWhenDetailsAreVisibleImagesAvailable.forEach { $0.isHidden = false }
            NSLayoutConstraint.deactivate(thumbnailRelatedConstraints)
            NSLayoutConstraint.activate(bigImageRelatedConstraints)
        } else if viewModel.areDetailsVisible && viewModel.areImagesHidden {
            viewsVisibleWhenDetailsAreVisibleImagesNotAvailable.forEach { $0.isHidden = false }
            NSLayoutConstraint.deactivate(thumbnailRelatedConstraints)
            NSLayoutConstraint.deactivate(bigImageRelatedConstraints)
        } else if !viewModel.areDetailsVisible && !viewModel.areImagesHidden {
            viewsVisibleWhenDetailsAreNotVisibleImagesAvailable.forEach { $0.isHidden = false }
            NSLayoutConstraint.activate(thumbnailRelatedConstraints)
            NSLayoutConstraint.deactivate(bigImageRelatedConstraints)
        } else if !viewModel.areDetailsVisible && viewModel.areImagesHidden {
            viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable.forEach { $0.isHidden = false }
            NSLayoutConstraint.deactivate(thumbnailRelatedConstraints)
            NSLayoutConstraint.deactivate(bigImageRelatedConstraints)
        }

        attributesCollectionView.backgroundColor = viewModel.contentsBackgroundColor
        attributesCollectionView.reloadData()
        attributesCollectionViewHeightConstraint.constant = attributesCollectionView.collectionViewLayout.collectionViewContentSize.height

        urlButton.setTitle(viewModel.urlButtonText, for: .normal)
        urlButton.tintColor = viewModel.urlButtonTextColor
        urlButton.titleLabel?.font = viewModel.urlButtonFont
        urlButton.imageView?.backgroundColor = .clear
        urlButton.setImage(viewModel.urlButtonImage, for: .normal)
        urlButton.semanticContentAttribute = .forceRightToLeft
        urlButton.imageEdgeInsets = .init(top: 1, left: 0, bottom: 0, right: -20)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        //Careful to set a value that is not too big so that it bleeds out when tilted to the max, due to the big image bleeding out from the holder
        setupParallaxEffect(forView: bigImageHolder, max: 24)
        setupParallaxEffect(forView: thumbnailImageView, max: 15)
    }

    //Have to recreate UIMotionEffect every time, after `layoutSubviews()` complete
    private func setupParallaxEffect(forView view: UIView, max: CGFloat) {
        view.motionEffects.forEach { view.removeMotionEffect($0) }

        let min = max
        let max = -max

        let xMotion = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        xMotion.minimumRelativeValue = min
        xMotion.maximumRelativeValue = max

        let yMotion = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        yMotion.minimumRelativeValue = min
        yMotion.maximumRelativeValue = max

        let motionEffectGroup = UIMotionEffectGroup()
        motionEffectGroup.motionEffects = [xMotion, yMotion]

        view.addMotionEffect(motionEffectGroup)
    }
}

extension CryptoKittyCardRowView: TokenRowView {
    func configure(tokenHolder: TokenHolder) {
        configure(viewModel: .init(tokenHolder: tokenHolder, areDetailsVisible: false))
    }
}

extension CryptoKittyCardRowView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.attributes.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CryptoKittyCAttributeCell.identifier, for: indexPath) as! CryptoKittyCAttributeCell
        if let viewModel = viewModel {
            let nameAndValues = viewModel.attributes[indexPath.row]
            cell.configure(viewModel: .init(
                    name: nameAndValues.name,
                    value: nameAndValues.value
            ))
        }
        return cell
    }
}
