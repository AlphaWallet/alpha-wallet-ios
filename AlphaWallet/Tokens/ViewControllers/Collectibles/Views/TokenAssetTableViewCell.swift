//
//  TokenAssetTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

//Very similar to NonFungibleRowView below, but keeping around to render FIFA tickets because some attributes are hardcoded
class Erc875NonFungibleRowView: TokenCardRowViewProtocol & UIView & SelectionPositioningView {
    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool  = false
    var additionalHeightToCompensateForAutoLayout: CGFloat = 0.0
    var shouldOnlyRenderIfHeightIsCached: Bool = false

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let tokenCountLabel = UILabel()

    var positioningView: UIView {
        thumbnailImageView
    }

    private var thumbnailImageView: WebImageView = {
        let imageView = WebImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    init(tokenView: TokenView, edgeInsets: UIEdgeInsets = .init(top: 16, left: 20, bottom: 16, right: 16)) {
        self.tokenView = tokenView
        super.init(frame: .zero)

        titleLabel.baselineAdjustment = .alignCenters
        tokenCountLabel.baselineAdjustment = .alignCenters
        descriptionLabel.baselineAdjustment = .alignCenters

        let col0 = thumbnailImageView
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5),
            [descriptionLabel, UIView.spacerWidth(flexible: true), tokenCountLabel].asStackView(spacing: 5)
        ].asStackView(axis: .vertical, spacing: 2)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 40),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: Erc875NonFungibleRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        titleLabel.text = viewModel.title
        thumbnailImageView.setImage(url: nil)
        descriptionLabel.attributedText = viewModel.attributedDescriptionText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: Erc875NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }

}

class NonFungibleRowView: TokenCardRowViewProtocol & UIView & SelectionPositioningView {
    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool = false
    var additionalHeightToCompensateForAutoLayout: CGFloat = 0.0
    var shouldOnlyRenderIfHeightIsCached: Bool = false

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    var positioningView: UIView {
        thumbnailImageView
    }

    private var thumbnailImageView: WebImageView = {
        let imageView = WebImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    init(tokenView: TokenView, edgeInsets: UIEdgeInsets = .init(top: 16, left: 20, bottom: 16, right: 16)) {
        self.tokenView = tokenView
        super.init(frame: .zero)

        titleLabel.baselineAdjustment = .alignCenters
        descriptionLabel.baselineAdjustment = .alignCenters

        let col0 = thumbnailImageView
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5),
            [descriptionLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5)
        ].asStackView(axis: .vertical, spacing: 2)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 40),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        titleLabel.text = viewModel.title
        thumbnailImageView.setImage(url: viewModel.imageUrl)
        descriptionLabel.attributedText = viewModel.attributedDescriptionText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, areDetailsVisible: areDetailsVisible, width: width))
    }
}

struct Erc875NonFungibleRowViewModel: TokenCardRowViewModelProtocol {
    private let tokenHolder: TokenHolder
    private let tokenView: TokenView
    private let assetDefinitionStore: AssetDefinitionStore
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenId: TokenId

    var contentsBackgroundColor: UIColor {
        return .clear
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        self.tokenView = tokenView
        self.assetDefinitionStore = assetDefinitionStore
        displayHelper = .init(contract: tokenHolder.contractAddress)
    }

    var title: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    var attributedDescriptionText: NSAttributedString {
        return .init(string: R.string.localizable.semifungiblesAssetsCount(_tokenCount), attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var _tokenCount: Int {

        Int(tokenHolder.values.valueIntValue ?? 0)
    }

    var tokenCount: String {
        return "x\(_tokenCount)"
    }

    var city: String {
        let value = tokenHolder.values.localityStringValue ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        if tokenHolder.hasAssetDefinition {
            return tokenHolder.values.categoryStringValue ?? "N/A"
        } else {
            //For ERC75 tokens, display the contract's name as the "title". https://github.com/alpha-wallet/alpha-wallet-ios/issues/664
            return tokenHolder.name
        }
    }

    var isMeetupContract: Bool {
        return tokenHolder.isSpawnableMeetupContract
    }

    var teams: String {
        if isMeetupContract && tokenHolder.values["expired"] != nil {
            return ""
        } else {
            let countryA = tokenHolder.values.countryAStringValue ?? ""
            let countryB = tokenHolder.values.countryBStringValue ?? ""
            return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values.sectionStringValue {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values.matchIntValue ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        return tokenHolder.values.venueStringValue ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var numero: String {
        if let num = tokenHolder.values.numeroIntValue {
            return String(num)
        } else {
            return "N/A"
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribable = tokenHolder.values.buildingSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    block(value)
                }
            }
        }
    }

    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void) {
        func updateStreetLocalityStateCountry(street: String?, locality: String?, state: String?, country: String?) {
            let values = [street, locality, state, country].compactMap { $0 }
            let string = values.joined(separator: ", ")
            block(string)
        }
        if let subscribable = tokenHolder.values.streetSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: self.tokenHolder.values.localitySubscribableStringValue,
                            state: self.tokenHolder.values.stateSubscribableStringValue,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }
        if let subscribable = tokenHolder.values.stateSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values.streetSubscribableStringValue,
                            locality: self.tokenHolder.values.localitySubscribableStringValue,
                            state: value,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let subscribable = tokenHolder.values.localitySubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values.streetSubscribableStringValue,
                            locality: value,
                            state: self.tokenHolder.values.stateSubscribableStringValue,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let country = tokenHolder.values.countryStringValue {
            updateStreetLocalityStateCountry(
                    street: self.tokenHolder.values.streetSubscribableStringValue,
                    locality: self.tokenHolder.values.localitySubscribableStringValue,
                    state: self.tokenHolder.values.stateSubscribableStringValue,
                    country: country
            )
        }
    }

    var time: String {
        let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }

    var tokenScriptHtml: (html: String, hash: Int) {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let html: String
        let style: String
        switch tokenView {
        case .view:
            (html, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, style) = xmlHandler.tokenViewIconifiedHtml
        }
        let hash = html.hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}

struct NonFungibleRowViewModel {
    private let tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let _tokenId: TokenId
    let areDetailsVisible: Bool
    let width: CGFloat
    let convertHtmlInDescription: Bool
    var contentsBackgroundColor: UIColor {
        return .clear
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId, areDetailsVisible: Bool, width: CGFloat, convertHtmlInDescription: Bool = true) {
        self.tokenHolder = tokenHolder
        self._tokenId = tokenId
        self.areDetailsVisible = areDetailsVisible
        self.width = width
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        self.convertHtmlInDescription = convertHtmlInDescription
    }

    var stateBackgroundColor: UIColor {
        return UIColor(red: 151, green: 151, blue: 151)
    }

    var tokenCountFont: UIFont {
        return Fonts.bold(size: 21)
    }

    var countColor: UIColor {
        return Colors.appHighlightGreen
    }

    var attributedDescriptionText: NSAttributedString {
        return .init(string: R.string.localizable.semifungiblesAssetsCount(Int(tokenHolder.values.valueIntValue ?? 0)), attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var bigImageBackgroundColor: UIColor {
        //Instead of checking the API for backgroundColor first, we use the backgroundColor returned by API only if we are sure, i.e. had manually verified
        if displayHelper.imageHasBackgroundColor {
            return .clear
        } else {
            if let color = tokenHolder.values.backgroundColorStringValue.nilIfEmpty {
                return UIColor(hex: color)
            } else {
                return UIColor(red: 247, green: 197, blue: 196)
            }
        }
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var titleFont: UIFont {
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 13 : 17)
    }

    var descriptionFont: UIFont {
        return Fonts.light(size: 13)
    }

    var stateColor: UIColor {
        return .white
    }

    var stateFont: UIFont {
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 10: 12)
    }

    var detailsFont: UIFont {
        return Fonts.light(size: 16)
    }

    var urlButtonText: String {
        return R.string.localizable.openSeaNonFungibleTokensUrlOpen(tokenHolder.name)
    }

    var title: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    var attributesTitleFont: UIFont {
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 11 : 15)
    }

    var attributesTitle: String {
        return displayHelper.attributesLabelName
    }

    var rankingsTitle: String {
        return displayHelper.rankingsLabelName
    }

    var statsTitle: String {
        return displayHelper.statsLabelName
    }

    var isAttributesTitleHidden: Bool {
        return !areDetailsVisible || attributes.isEmpty
    }

    var isRankingsTitleHidden: Bool {
        return !areDetailsVisible || rankings.isEmpty
    }

    var isStatsTitleHidden: Bool {
        return !areDetailsVisible || stats.isEmpty
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 11 : 14)
    }

    var nonFungibleIdIconText: String {
        return "#"
    }

    var nonFungibleIdIconTextColor: UIColor {
        return .init(red: 192, green: 192, blue: 192)
    }

    var nonFungibleIdTextColor: UIColor {
        return .init(red: 155, green: 155, blue: 155)
    }

    var generationTextColor: UIColor {
        return .init(red: 155, green: 155, blue: 155)
    }

    var cooldownTextColor: UIColor {
        return .init(red: 155, green: 155, blue: 155)
    }

    var generationIcon: UIImage {
        return R.image.generation()!
    }

    var cooldownIcon: UIImage {
        return R.image.cooldown()!
    }

    var tokenId: String {
        return tokenHolder.values.tokenIdStringValue ?? ""
    }

    var subtitle1: String? {
        guard let name = displayHelper.subtitle1TraitName else { return nil }
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        guard let generation = traits.first(where: { $0.type == name }) else { return nil }
        let value = displayHelper.mapTraitsToDisplayValue(name: name, value: generation.value)
        return value
    }

    var subtitle2: String? {
        guard let name = displayHelper.subtitle2TraitName else { return nil }
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        guard let cooldown = traits.first(where: { $0.type == name }) else { return nil }
        let value = displayHelper.mapTraitsToDisplayValue(name: name, value: cooldown.value)
        return value
    }

    var subtitle3: String? {
        guard let name = displayHelper.subtitle3TraitName else { return nil }
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        guard let cooldown = traits.first(where: { $0.type == name }) else { return nil }
        let value = displayHelper.mapTraitsToDisplayValue(name: name, value: cooldown.value)
        return value
    }

    var description: NSAttributedString {
        return convertDescriptionToAttributedString(asHTML: true)
    }

    //This is needed because conversion from HTML to NSAttributedString is problematic if we do it while we are animating UI (force touch + peek as of writing this
    var descriptionWithoutConvertingHtml: NSAttributedString {
        return convertDescriptionToAttributedString(asHTML: false)
    }

    var thumbnailImageUrl: URL? {
        return tokenHolder.values.thumbnailUrlUrlValue
    }

    var imageUrl: URL? {
        return tokenHolder.values.imageUrlUrlValue
    }

    var externalLink: URL? {
        return tokenHolder.values.externalLinkUrlValue
    }

    var externalLinkButtonHidden: Bool {
        return externalLink == nil
    }

    var attributes: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayAttribute(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var rankings: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayRanking(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var stats: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayStat(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var areImagesHidden: Bool {
        return tokenHolder.status == .availableButDataUnavailable || imageUrl == nil
    }

    var isDescriptionHidden: Bool {
        return tokenHolder.status == .availableButDataUnavailable
    }

    var urlButtonTextColor: UIColor {
        return UIColor(red: 84, green: 84, blue: 84)
    }

    var urlButtonFont: UIFont {
        return Fonts.semibold(size: 12)
    }

    var urlButtonImage: UIImage {
        return R.image.openSeaNonFungibleButtonArrow()!
    }

    private func convertDescriptionToAttributedString(asHTML: Bool) -> NSAttributedString {
        let string = tokenHolder.values.descriptionStringValue ?? ""
        //.unicode, not .utf8, otherwise Chinese will turn garbage
        let htmlData = string.data(using: .unicode)
        let options: [NSAttributedString.DocumentReadingOptionKey: NSAttributedString.DocumentType]
        if asHTML {
            options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
        } else {
            options = [:]
        }
        return (try? NSMutableAttributedString(data: htmlData ?? Data(), options: options, documentAttributes: nil)) ?? NSAttributedString(string: string)
    }

    private func mapTraitsToProperName(name: String, value: String) -> OpenSeaNonFungibleTokenAttributeCellViewModel {
        let displayName = displayHelper.mapTraitsToDisplayName(name: name)
        let displayValue = displayHelper.mapTraitsToDisplayValue(name: name, value: value)
        return OpenSeaNonFungibleTokenAttributeCellViewModel(name: displayName, value: displayValue)
    }

    var areSubtitlesHidden: Bool {
        return subtitle1 == nil && subtitle2 == nil && subtitle3 == nil
    }

    var isSubtitle1Hidden: Bool {
        return subtitle1 == nil
    }

    var isSubtitle2Hidden: Bool {
        return subtitle2 == nil
    }

    var isSubtitle3Hidden: Bool {
        return subtitle3 == nil
    }

    //We let the big image bleed out of its container view because CryptoKitty images has a huge empty marge around the kitties. Careful that this also fits iPhone 5s
    var bleedForBigImage: CGFloat {
        if displayHelper.hasLotsOfEmptySpaceAroundBigImage {
            if ScreenChecker().isNarrowScreen {
                return 24
            } else {
                return 34
            }
        } else {
            return 0
        }
    }
}
