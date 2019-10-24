// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol OpenSeaNonFungibleTokenCardRowViewDelegate: class {
    func didTapURL(url: URL)
}

class OpenSeaNonFungibleTokenCardRowView: UIView, TokenCardRowViewProtocol {
    private let mainVerticalStackView: UIStackView = [].asStackView(axis: .vertical, contentHuggingPriority: .required)
    private let thumbnailImageView = UIImageView()
    private let bigImageBackground = UIView()
    private let bigImageView = UIImageView()
    //the SVG from CryptoKitty usually has lots of white space around the kitty. We add a container around the image view and let it bleed out a little for CryptoKitties
    private let bigImageHolder = UIView()
    private let titleLabel = UILabel()
    private let spacers = (
            aboveTitle: UIView.spacer(height: 20),
            atTop: UIView.spacer(height: 20),
            belowDescription: UIView.spacer(height: 20),
            belowState: UIView.spacer(height: 10),
            aboveHorizontalSubtitleStackView: UIView.spacer(height: 20),
            belowHorizontalSubtitleStackView: UIView.spacer(height: 20),
            belowVerticalSubtitleStackView: UIView.spacer(height: 16),
            belowAttributesLabel: UIView.spacer(height: 20),
            aboveStatsLabel: UIView.spacer(height: 20),
            belowStatsLabel: UIView.spacer(height: 20),
            aboveRankingsLabel: UIView.spacer(height: 20),
            belowRankingsLabel: UIView.spacer(height: 20),
            atBottom: UIView.spacer(height: 16)
    )
    private let outerHorizontalMargin = CGFloat(21)
    private let backgroundCornerRadius = Metrics.CornerRadius.box
    private let horizontalSubtitleStackView: UIStackView = [].asStackView(alignment: .center)
    private let verticalSubtitleStackView: UIStackView = [].asStackView(axis: .vertical, alignment: .leading)
    //TODO Name is too-specific for generation and cooldown, but the icons really are for those. We can rename (or remove this TODO once we are clean whether the icons are shown if the values displayed aren't generation/cooldown
    private let verticalGenerationIconImageView = UIImageView()
    private let verticalCooldownIconImageView = UIImageView()
    private let verticalSubtitle1Label = UILabel()
    private let verticalSubtitle2And3Label = UILabel()
    private let nonFungibleIdIconLabel = UILabel()
    private let generationIconImageView = UIImageView()
    private let cooldownIconImageView = UIImageView()
    private let nonFungibleIdLabel = UILabel()
    private let subtitle1Label = UILabel()
    private let subtitle2And3Label = UILabel()
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
    private let rankingsLabel = UILabel()
    private let rankingsCollectionView = { () -> UICollectionView in
        let layout = UICollectionViewFlowLayout()
        //3-column for iPhone 6s and above, 2-column for iPhone 5
        layout.itemSize = CGSize(width: 105, height: 30)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 00
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    lazy private var rankingsCollectionViewHeightConstraint = rankingsCollectionView.heightAnchor.constraint(equalToConstant: 100)
    private let statsLabel = UILabel()
    private let statsCollectionView = { () -> UICollectionView in
        let layout = UICollectionViewFlowLayout()
        //3-column for iPhone 6s and above, 2-column for iPhone 5
        layout.itemSize = CGSize(width: 105, height: 30)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 00
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    lazy private var statsCollectionViewHeightConstraint = statsCollectionView.heightAnchor.constraint(equalToConstant: 100)
    private let urlButton = UIButton(type: .system)
    private let urlButtonHolder = [].asStackView(axis: .horizontal, alignment: .leading)
    private var viewModel: OpenSeaNonFungibleTokenCardRowViewModel?
    private var thumbnailRelatedConstraints = [NSLayoutConstraint]()
    //Sets a default which is ignored. At runtime, we recalculate constant based on image's aspect ratio so the image can always fill the width
    lazy private var bigImageHolderHeightConstraint = bigImageView.heightAnchor.constraint(equalToConstant: 300)
    private var bigImageRelatedConstraints = [NSLayoutConstraint]()
    private var bigImageViewRelatedConstraintsWithPositiveBleed = [NSLayoutConstraint]()
    private var bigImageViewRelatedConstraintsWithNegativeBleed = [NSLayoutConstraint]()
    private var viewsVisibleWhenDetailsAreVisibleImagesAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreNotVisibleImagesAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreVisibleImagesNotAvailable = [UIView]()
    private var viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable = [UIView]()
    private var currentDisplayedImageUrl: URL?
    private var checkboxRelatedConstraintsWhenShown = [NSLayoutConstraint]()
    private var checkboxRelatedConstraintsWhenHidden = [NSLayoutConstraint]()

    var background = UIView()
    var stateLabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool {
        didSet {
            checkboxImageView.isHidden = !showCheckbox
            if showCheckbox {
                NSLayoutConstraint.deactivate(checkboxRelatedConstraintsWhenHidden)
                NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenShown)
            } else {
                NSLayoutConstraint.deactivate(checkboxRelatedConstraintsWhenShown)
                NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenHidden)
            }
        }
    }
    //Just to adhere to protocol
    var areDetailsVisible = false

    var checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
    weak var delegate: OpenSeaNonFungibleTokenCardRowViewDelegate?

    init(tokenView: TokenView, showCheckbox: Bool = false) {
        self.showCheckbox = showCheckbox
        self.tokenView = tokenView

        super.init(frame: .zero)

        addSubview(checkboxImageView)
        checkboxImageView.isHidden = !showCheckbox

        bigImageView.translatesAutoresizingMaskIntoConstraints = false
        bigImageHolder.addSubview(bigImageView)
        bigImageHolder.isHidden = true
        bigImageBackground.isHidden = true

        urlButtonHolder.isHidden = true
        urlButton.addTarget(self, action: #selector(tappedUrl), for: .touchUpInside)

        attributesCollectionView.register(OpenSeaNonFungibleTokenTraitCell.self, forCellWithReuseIdentifier: OpenSeaNonFungibleTokenTraitCell.identifier)
        attributesCollectionView.isUserInteractionEnabled = false
        attributesCollectionView.dataSource = self

        rankingsCollectionView.register(OpenSeaNonFungibleTokenTraitCell.self, forCellWithReuseIdentifier: OpenSeaNonFungibleTokenTraitCell.identifier)
        rankingsCollectionView.isUserInteractionEnabled = false
        rankingsCollectionView.dataSource = self

        statsCollectionView.register(OpenSeaNonFungibleTokenTraitCell.self, forCellWithReuseIdentifier: OpenSeaNonFungibleTokenTraitCell.identifier)
        statsCollectionView.isUserInteractionEnabled = false
        statsCollectionView.dataSource = self

        setupLayout()
    }

    private func setupLayout() {
        addSubview(background)

        checkboxImageView.translatesAutoresizingMaskIntoConstraints = false

        background.translatesAutoresizingMaskIntoConstraints = false

        bigImageBackground.translatesAutoresizingMaskIntoConstraints = false
        bigImageBackground.layer.cornerRadius = backgroundCornerRadius
        background.addSubview(bigImageBackground)

        horizontalSubtitleStackView.addArrangedSubviews([nonFungibleIdIconLabel, .spacerWidth(3), nonFungibleIdLabel, .spacerWidth(7), generationIconImageView, subtitle1Label, .spacerWidth(7), cooldownIconImageView, subtitle2And3Label])

        let generationStackView = [verticalGenerationIconImageView, verticalSubtitle1Label].asStackView(spacing: 0, contentHuggingPriority: .required)
        let cooldownStackView = [verticalCooldownIconImageView, verticalSubtitle2And3Label].asStackView(spacing: 0, contentHuggingPriority: .required)
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
            spacers.belowVerticalSubtitleStackView,
            descriptionLabel,
            spacers.belowDescription,
            attributesLabel,
            spacers.belowAttributesLabel,
            attributesCollectionView,
            spacers.aboveRankingsLabel,
            rankingsLabel,
            spacers.belowRankingsLabel,
            rankingsCollectionView,
            spacers.aboveStatsLabel,
            statsLabel,
            spacers.belowStatsLabel,
            statsCollectionView,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required, alignment: .leading)

        let col1 = thumbnailImageView

        let bodyStackView = [UIView.spacerWidth(outerHorizontalMargin), col0, col1].asStackView(axis: .horizontal, contentHuggingPriority: .required, alignment: .top)

        let urlButtonInnerHolder = [
            .spacer(height: 20),
            urlButton,
        ].asStackView(axis: .vertical, alignment: .leading)
        urlButtonHolder.addArrangedSubviews([UIView.spacerWidth(outerHorizontalMargin), urlButtonInnerHolder])

        mainVerticalStackView.addArrangedSubviews([
            spacers.atTop,
            bigImageHolder,
            bodyStackView,
            urlButtonHolder,
            spacers.atBottom
        ])
        mainVerticalStackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(mainVerticalStackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin = CGFloat(7)
        let yMargin = CGFloat(5)
        checkboxRelatedConstraintsWhenShown.append(checkboxImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
        checkboxRelatedConstraintsWhenShown.append(checkboxImageView.centerYAnchor.constraint(equalTo: centerYAnchor))
        checkboxRelatedConstraintsWhenShown.append(background.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: xMargin))
        if ScreenChecker().isNarrowScreen {
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 20))
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 20))
        } else {
            //Have to be hardcoded and not rely on the image's size because different string lengths for the text fields can force the checkbox to shrink
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 28))
            checkboxRelatedConstraintsWhenShown.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 28))
        }
        checkboxRelatedConstraintsWhenHidden.append(background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
        if showCheckbox {
            NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenShown)
        } else {
            NSLayoutConstraint.activate(checkboxRelatedConstraintsWhenHidden)
        }

        thumbnailRelatedConstraints = [
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 150),
            thumbnailImageView.widthAnchor.constraint(equalTo: thumbnailImageView.heightAnchor),
            thumbnailImageView.heightAnchor.constraint(greaterThanOrEqualTo: col0.heightAnchor),
        ]

        let marginForBigImageView = CGFloat(1)
        bigImageRelatedConstraints = [
            bigImageHolder.widthAnchor.constraint(equalTo: mainVerticalStackView.widthAnchor),
            bigImageHolderHeightConstraint,
            bigImageBackground.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: marginForBigImageView),
            bigImageBackground.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -marginForBigImageView),
            bigImageBackground.topAnchor.constraint(equalTo: background.topAnchor, constant: marginForBigImageView),
            bigImageBackground.bottomAnchor.constraint(equalTo: bigImageHolder.bottomAnchor, constant: 10),
        ]

        bigImageViewRelatedConstraintsWithPositiveBleed = [
            bigImageView.bottomAnchor.constraint(equalTo: bigImageHolder.bottomAnchor, constant: 0),
            bigImageView.trailingAnchor.constraint(equalTo: bigImageHolder.trailingAnchor, constant: 0),
        ]
        bigImageViewRelatedConstraintsWithNegativeBleed = [
            bigImageView.topAnchor.constraint(equalTo: bigImageHolder.topAnchor, constant: 0),
            bigImageView.leadingAnchor.constraint(equalTo: bigImageHolder.leadingAnchor, constant: 0),
        ]

        NSLayoutConstraint.activate([
            mainVerticalStackView.anchorsConstraint(to: background, edgeInsets: .init(top: marginForBigImageView, left: 0, bottom: 0, right: 0)),

            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),

            stateLabel.heightAnchor.constraint(equalToConstant: 22),

            //It is important to anchor the collection view to an outer stackview (which has aligment=.fill) instead of child stackviews which does not have alignment=.fill
            attributesCollectionView.leadingAnchor.constraint(equalTo: mainVerticalStackView.leadingAnchor, constant: outerHorizontalMargin),
            attributesCollectionView.trailingAnchor.constraint(equalTo: mainVerticalStackView.trailingAnchor, constant: -outerHorizontalMargin),
            attributesCollectionViewHeightConstraint,

            //It is important to anchor the collection view to the outermost stackview (which has aligment=.fill) instead of child stackviews which does not have alignment=.fill
            rankingsCollectionView.leadingAnchor.constraint(equalTo: attributesCollectionView.leadingAnchor),
            rankingsCollectionView.trailingAnchor.constraint(equalTo: attributesCollectionView.trailingAnchor),
            rankingsCollectionViewHeightConstraint,

            verticalGenerationIconImageView.widthAnchor.constraint(equalTo: verticalCooldownIconImageView.widthAnchor),
            verticalCooldownIconImageView.widthAnchor.constraint(equalTo: verticalCooldownIconImageView.heightAnchor),

            //It is important to anchor the collection view to the outermost stackview (which has aligment=.fill) instead of child stackviews which does not have alignment=.fill
            statsCollectionView.leadingAnchor.constraint(equalTo: attributesCollectionView.leadingAnchor),
            statsCollectionView.trailingAnchor.constraint(equalTo: attributesCollectionView.trailingAnchor),
            statsCollectionViewHeightConstraint,

            descriptionLabel.widthAnchor.constraint(equalTo: col0.widthAnchor),

            //Otherwise the button might not appear correctly
            urlButton.heightAnchor.constraint(equalToConstant: 20),

            bigImageViewRelatedConstraintsWithPositiveBleed,
            bigImageViewRelatedConstraintsWithNegativeBleed,
            thumbnailRelatedConstraints,
        ])

        viewsVisibleWhenDetailsAreNotVisibleImagesAvailable = [
            spacers.aboveTitle,
            verticalSubtitleStackView,
            thumbnailImageView,
            spacers.belowVerticalSubtitleStackView,
        ]

        viewsVisibleWhenDetailsAreVisibleImagesAvailable = [
            attributesLabel,
            attributesCollectionView,
            rankingsLabel,
            rankingsCollectionView,
            statsLabel,
            statsCollectionView,
            urlButtonHolder,
            bigImageHolder,
            bigImageBackground,
            horizontalSubtitleStackView,
            spacers.aboveHorizontalSubtitleStackView,
            spacers.belowHorizontalSubtitleStackView,
            spacers.belowDescription,
            descriptionLabel,
            spacers.atBottom,
        ]
        viewsVisibleWhenDetailsAreNotVisibleImagesNotAvailable = [
            spacers.atTop,
            spacers.belowState,
            spacers.atBottom,
        ]
        viewsVisibleWhenDetailsAreVisibleImagesNotAvailable = [
            spacers.atTop,
            spacers.belowState,
            urlButtonHolder,
            spacers.atBottom,
        ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tappedUrl() {
        guard let url = viewModel?.externalLink else { return }
        delegate?.didTapURL(url: url)
    }

    func configure(tokenHolder: TokenHolder, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        configure(viewModel: .init(tokenHolder: tokenHolder, areDetailsVisible: areDetailsVisible, width: width))
    }

    func configure(viewModel: OpenSeaNonFungibleTokenCardRowViewModel) {
        self.viewModel = viewModel

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = backgroundCornerRadius
        background.layer.shadowRadius = 3
        background.layer.shadowColor = UIColor.black.cgColor
        background.layer.shadowOffset = CGSize(width: 0, height: 0)
        background.layer.shadowOpacity = 0.14
        background.layer.borderColor = UIColor.black.cgColor

        stateLabel.layer.cornerRadius = 10
        stateLabel.clipsToBounds = true
        stateLabel.textColor = viewModel.stateColor
        stateLabel.font = viewModel.stateFont

        nonFungibleIdIconLabel.text = viewModel.nonFungibleIdIconText
        nonFungibleIdIconLabel.textColor = viewModel.nonFungibleIdIconTextColor
        generationIconImageView.image = viewModel.generationIcon
        cooldownIconImageView.image = viewModel.cooldownIcon
        verticalGenerationIconImageView.image = viewModel.generationIcon
        verticalCooldownIconImageView.image = viewModel.cooldownIcon

        nonFungibleIdLabel.textColor = viewModel.nonFungibleIdTextColor
        subtitle1Label.textColor = viewModel.generationTextColor
        subtitle2And3Label.textColor = viewModel.cooldownTextColor
        nonFungibleIdLabel.font = viewModel.subtitleFont
        subtitle1Label.font = viewModel.subtitleFont
        subtitle2And3Label.font = viewModel.subtitleFont

        verticalSubtitle1Label.textColor = viewModel.generationTextColor
        verticalSubtitle2And3Label.textColor = viewModel.cooldownTextColor
        verticalSubtitle1Label.font = viewModel.subtitleFont
        verticalSubtitle2And3Label.font = viewModel.subtitleFont

        nonFungibleIdLabel.text = viewModel.tokenId
        subtitle1Label.text = viewModel.subtitle1
        verticalSubtitle1Label.text = viewModel.subtitle1
        if viewModel.isSubtitle3Hidden {
            subtitle2And3Label.text = viewModel.subtitle2
            verticalSubtitle2And3Label.text = viewModel.subtitle2
        } else {
            if let subtitle2 = viewModel.subtitle2, let subtitle3 = viewModel.subtitle3 {
                subtitle2And3Label.text = "\(subtitle2) / \(subtitle3)"
                verticalSubtitle2And3Label.text = "\(subtitle2) / \(subtitle3)"
            } else {
                subtitle2And3Label.text = viewModel.subtitle2
                verticalSubtitle2And3Label.text = viewModel.subtitle2
            }
        }

        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = viewModel.titleColor
        descriptionLabel.font = viewModel.descriptionFont

        titleLabel.numberOfLines = 0
        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont

        attributesLabel.textColor = viewModel.titleColor
        attributesLabel.font = viewModel.attributesTitleFont

        rankingsLabel.textColor = viewModel.titleColor
        rankingsLabel.font = viewModel.attributesTitleFont

        statsLabel.textColor = viewModel.titleColor
        statsLabel.font = viewModel.attributesTitleFont

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.backgroundColor = .clear
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = backgroundCornerRadius

        bigImageBackground.backgroundColor = viewModel.bigImageBackgroundColor
        bigImageView.contentMode = .scaleAspectFit
        bigImageView.backgroundColor = .clear
        bigImageHolder.backgroundColor = .clear
        bigImageView.clipsToBounds = true
        bigImageView.layer.cornerRadius = backgroundCornerRadius

        let bleedForBigImage = viewModel.bleedForBigImage
        for each in bigImageViewRelatedConstraintsWithPositiveBleed {
            each.constant = bleedForBigImage
        }
        for each in bigImageViewRelatedConstraintsWithNegativeBleed {
            each.constant = -bleedForBigImage
        }

        //WORKAROUND: If we convert from HTML to NSAttributedString while presenting the view controller containing this view, the view controller's animation breaks. As of iOS 12, it shows the view controller immediately followed by presenting it normally, sliding up from the bottom of the screen. i.e. the view controller appears twice. Since the description isn't shown initially, we might as well don't convert now and even gain a slight bit of performance enhancement for doing less work
        if viewModel.areDetailsVisible {
            if viewModel.convertHtmlInDescription {
                descriptionLabel.attributedText = viewModel.description
            } else {
                descriptionLabel.attributedText = viewModel.descriptionWithoutConvertingHtml
            }
        }

        titleLabel.text = viewModel.title

        attributesLabel.text = viewModel.attributesTitle

        rankingsLabel.text = viewModel.rankingsTitle

        statsLabel.text = viewModel.statsTitle

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
                    strongSelf.bigImageHolderHeightConstraint.constant = image.size.height / image.size.width * strongSelf.bigImageHolder.frame.size.width
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

        //Can only set isHidden to true and never false here, because we might have set isHidden to true earlier depending on whether details are available
        if viewModel.areSubtitlesHidden {
            verticalSubtitleStackView.isHidden = true
            horizontalSubtitleStackView.isHidden = true
            spacers.aboveHorizontalSubtitleStackView.isHidden = true
        }

        verticalGenerationIconImageView.isHidden = viewModel.isSubtitle1Hidden
        generationIconImageView.isHidden = viewModel.isSubtitle1Hidden
        verticalCooldownIconImageView.isHidden = viewModel.isSubtitle2Hidden
        cooldownIconImageView.isHidden = viewModel.isSubtitle2Hidden

        relayoutParent(withWidth: viewModel.width)

        attributesCollectionView.backgroundColor = viewModel.contentsBackgroundColor
        attributesCollectionViewHeightConstraint.constant = attributesCollectionView.collectionViewLayout.collectionViewContentSize.height

        rankingsCollectionView.backgroundColor = viewModel.contentsBackgroundColor
        rankingsCollectionViewHeightConstraint.constant = rankingsCollectionView.collectionViewLayout.collectionViewContentSize.height

        statsCollectionView.backgroundColor = viewModel.contentsBackgroundColor
        statsCollectionViewHeightConstraint.constant = statsCollectionView.collectionViewLayout.collectionViewContentSize.height

        urlButton.setTitle(viewModel.urlButtonText, for: .normal)
        urlButton.tintColor = viewModel.urlButtonTextColor
        urlButton.titleLabel?.font = viewModel.urlButtonFont
        urlButton.imageView?.backgroundColor = .clear
        urlButton.setImage(viewModel.urlButtonImage, for: .normal)
        urlButton.semanticContentAttribute = .forceRightToLeft
        urlButton.imageEdgeInsets = .init(top: 1, left: 0, bottom: 0, right: -20)

        //Careful to not set it to false
        if viewModel.externalLinkButtonHidden {
            urlButtonHolder.isHidden = true
        }

        attributesLabel.isHidden = viewModel.isAttributesTitleHidden
        spacers.belowDescription.isHidden = viewModel.isAttributesTitleHidden
        spacers.belowAttributesLabel.isHidden = viewModel.isAttributesTitleHidden

        rankingsLabel.isHidden = viewModel.isRankingsTitleHidden
        spacers.aboveRankingsLabel.isHidden = viewModel.isRankingsTitleHidden
        spacers.belowRankingsLabel.isHidden = viewModel.isRankingsTitleHidden

        statsLabel.isHidden = viewModel.isStatsTitleHidden
        spacers.aboveStatsLabel.isHidden = viewModel.isStatsTitleHidden
        spacers.belowStatsLabel.isHidden = viewModel.isStatsTitleHidden
    }

    //So collection views know the width to calculate their "full" height so they don't need to scroll
    private func relayoutParent(withWidth width: CGFloat) {
        guard let viewModel = viewModel else { return }
        guard viewModel.width > 0 else { return }
        var f = frame
        f.size.width = viewModel.width
        superview?.frame = f
        superview?.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        //Careful to set a value that is not too big so that it bleeds out when tilted to the max, due to the big image bleeding out from the holder
        setupParallaxEffect(forView: bigImageHolder, max: 24)
        setupParallaxEffect(forView: thumbnailImageView, max: 15)
    }
}

extension OpenSeaNonFungibleTokenCardRowView: TokenRowView {
    func configure(tokenHolder: TokenHolder) {
        configure(viewModel: .init(tokenHolder: tokenHolder, areDetailsVisible: false, width: 0))
    }
}

extension OpenSeaNonFungibleTokenCardRowView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        switch collectionView {
        case attributesCollectionView:
            return viewModel.attributes.count
        case rankingsCollectionView:
            return viewModel.rankings.count
        case statsCollectionView:
            return viewModel.stats.count
        default:
            return 0
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OpenSeaNonFungibleTokenTraitCell.identifier, for: indexPath) as! OpenSeaNonFungibleTokenTraitCell
        if let viewModel = viewModel {
            let nameAndValues: OpenSeaNonFungibleTokenAttributeCellViewModel
            switch collectionView {
            case attributesCollectionView:
                nameAndValues = viewModel.attributes[indexPath.row]
            case rankingsCollectionView:
                nameAndValues = viewModel.rankings[indexPath.row]
            default:
                nameAndValues = viewModel.stats[indexPath.row]
            }
            cell.configure(viewModel: .init(
                    name: nameAndValues.name,
                    value: nameAndValues.value
            ))
        }
        return cell
    }
}
