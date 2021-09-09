//
//  TokenAssetTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

class SimplifiedTokenCardRowView: TokenCardRowViewProtocol & UIView & SelectionPositioningView {
    
    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool  = false
    var additionalHeightToCompensateForAutoLayout: CGFloat = 0.0
    var shouldOnlyRenderIfHeightIsCached: Bool = false

//    private var viewModel: TokenAssetTableViewCellViewModel?
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let tokenCountLabel = UILabel()

    var positioningView: UIView {
        thumbnailImageView
    }

    private var thumbnailImageView: WebImageView = {
        let imageView = WebImageView(type: .thumbnail)
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

    func configure(viewModel: SimplifiedTokenCardRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
//        background.backgroundColor = viewModel.contentsBackgroundColor

//        tokenCountLabel.textColor = viewModel.countColor
//        tokenCountLabel.font = viewModel.tokenCountFont
//        tokenCountLabel.text = viewModel.tokenCount

        titleLabel.text = viewModel.title
        thumbnailImageView.url = nil//viewModel.imageUrl
        descriptionLabel.attributedText = viewModel.attributedSescriptionText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: SimplifiedTokenCardRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }

}

class SimplifiedBackedOpenSeaTokenCardRowView: TokenCardRowViewProtocol & UIView & SelectionPositioningView {

    var positioningView: UIView {
        return thumbnailImageView
    }

    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool = false
    var additionalHeightToCompensateForAutoLayout: CGFloat = 0.0
    var shouldOnlyRenderIfHeightIsCached: Bool = false

//    private let background = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let tokenCountLabel = UILabel()

    private var thumbnailImageView: WebImageView = {
        let imageView = WebImageView(type: .thumbnail)
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
//            thumbnailImageView.heightAnchor.constraint(equalToConstant: 40),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: SimplifiedOpenSeaNonFungibleTokenCardRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
//        background.backgroundColor = viewModel.contentsBackgroundColor

//        stateLabel.backgroundColor = viewModel.stateBackgroundColor
//        stateLabel.layer.cornerRadius = 8
//        stateLabel.clipsToBounds = true
//        stateLabel.textColor = viewModel.stateColor
//        stateLabel.font = viewModel.subtitleFont

//        tokenCountLabel.textColor = viewModel.countColor
//        tokenCountLabel.font = viewModel.tokenCountFont
//        tokenCountLabel.text = viewModel.tokenCount

        titleLabel.text = viewModel.title

        thumbnailImageView.url = viewModel.imageUrl
        descriptionLabel.attributedText = viewModel.attributedDescriptionText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: SimplifiedOpenSeaNonFungibleTokenCardRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, areDetailsVisible: areDetailsVisible, width: width))
    }
}

struct SimplifiedTokenCardRowViewModel: TokenCardRowViewModelProtocol {
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
        let tokenId = tokenHolder.values["tokenId"]?.stringValue ?? ""
        if let name = tokenHolder.values["name"]?.stringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    var attributedSescriptionText: NSAttributedString {
        return .init(string: "Assets \(tokenHolder.tokens.count) | Fixed Fungible Token", attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var tokenCount: String {
        return "x\(tokenHolder.tokens.count)"
    }

    var city: String {
        let value = tokenHolder.values["locality"]?.stringValue ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        if tokenHolder.hasAssetDefinition {
            return tokenHolder.values["category"]?.stringValue ?? "N/A"
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
            let countryA = tokenHolder.values["countryA"]?.stringValue ?? ""
            let countryB = tokenHolder.values["countryB"]?.stringValue ?? ""
            return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values["section"]?.stringValue {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values["match"]?.intValue ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        return tokenHolder.values["venue"]?.stringValue ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var numero: String {
        if let num = tokenHolder.values["numero"]?.intValue {
            return String(num)
        } else {
            return "N/A"
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["building"]?.value {
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
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["street"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                            state: self.tokenHolder.values["state"]?.subscribableStringValue,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["state"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values["street"]?.subscribableStringValue,
                            locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                            state: value,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }

        if case .some(.subscribable(let subscribable)) = tokenHolder.values["locality"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values["street"]?.subscribableStringValue,
                            locality: value,
                            state: self.tokenHolder.values["state"]?.subscribableStringValue,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }

        if let country = tokenHolder.values["country"]?.stringValue {
            updateStreetLocalityStateCountry(
                    street: self.tokenHolder.values["street"]?.subscribableStringValue,
                    locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                    state: self.tokenHolder.values["state"]?.subscribableStringValue,
                    country: country
            )
        }
    }

    var time: String {
        let value = tokenHolder.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
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

struct SimplifiedOpenSeaNonFungibleTokenCardRowViewModel {
    //private static var imageGenerator = ConvertSVGToPNG()
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

    var tokenCount: String {
        return "x\(tokenHolder.tokens.count)"
    }

    var attributedDescriptionText: NSAttributedString {
        return .init(string: "Assets \(tokenHolder.tokens.count) | Fixed Non Fungible Token", attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var bigImageBackgroundColor: UIColor {
        //Instead of checking the API for backgroundColor first, we use the backgroundColor returned by API only if we are sure, i.e. had manually verified
        if displayHelper.imageHasBackgroundColor {
            return .clear
        } else {
            if let color = tokenHolder.values["backgroundColor"]?.stringValue.nilIfEmpty {
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
        let tokenId = tokenHolder.values["tokenId"]?.stringValue ?? ""
        if let name = tokenHolder.values["name"]?.stringValue.nilIfEmpty {
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
        return tokenHolder.values["tokenId"]?.stringValue ?? ""
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
        guard let url = tokenHolder.values["thumbnailUrl"]?.stringValue else { return nil }
        return URL(string: url)
    }

    var imageUrl: URL? {
        guard let url = tokenHolder.values["imageUrl"]?.stringValue else { return nil }
        return URL(string: url)
    }

    var externalLink: URL? {
        guard let url = tokenHolder.values["externalLink"]?.stringValue else { return nil }
        return URL(string: url)
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
        let string = tokenHolder.values["description"]?.stringValue ?? ""
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
