// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

struct CryptoKittyCardRowViewModel {
    static var imageGenerator = GenerateCryptoKittyPNGFromSVG()

    let tokenHolder: TokenHolder

    let areDetailsVisible: Bool

    var bigImage: Promise<UIImage>?

    init(tokenHolder: TokenHolder, areDetailsVisible: Bool) {
        self.tokenHolder = tokenHolder
        self.areDetailsVisible = areDetailsVisible
        let tokenId = tokenHolder.values["tokenId"] as? String
        self.bigImage = CryptoKittyCardRowViewModel.imageGenerator.withDownloadedImage(fromURL: imageUrl, forTokenId: tokenId)
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var bigImageBackgroundColor: UIColor {
        return UIColor(red: 247, green: 197, blue: 196)
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var titleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 13)!
        } else {
            return Fonts.semibold(size: 17)!
        }
    }

    var descriptionFont: UIFont {
        return Fonts.light(size: 13)!
    }

    var stateColor: UIColor {
        return .white
    }

    var stateFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 10)!
        } else {
            return Fonts.semibold(size: 12)!
        }
    }

    var detailsFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var urlButtonText: String {
        return R.string.localizable.cryptoKittiesUrlOpen()
    }

    var title: String {
        let tokenId = tokenHolder.values["tokenId"] as? String ?? ""
        return R.string.localizable.cryptoKittiesCatName(tokenId)
    }

    var attributesTitleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 11)!
        } else {
            return Fonts.semibold(size: 15)!
        }
    }

    var attributesTitle: String {
        return R.string.localizable.cryptoKittiesCattributesTitle()
    }

    var subtitleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 11)!
        } else {
            return Fonts.semibold(size: 14)!
        }
    }

    var kittyIdIconText: String {
        return "#"
    }

    var kittyIdIconTextColor: UIColor {
        return .init(red: 192, green: 192, blue: 192)
    }

    var kittyIdTextColor: UIColor {
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
        return tokenHolder.values["tokenId"] as? String ?? ""
    }

    var generation: String {
        let traits =  tokenHolder.values["traits"] as? [CryptoKittyTrait] ?? []
        if let generation = traits.first(where: { $0.type == CryptoKitty.generationTraitName }) {
            return R.string.localizable.cryptoKittiesGeneration(generation.value)
        } else {
            return ""
        }
    }

    var cooldown: String {
        let traits =  tokenHolder.values["traits"] as? [CryptoKittyTrait] ?? []
        if let cooldown = traits.first(where: { $0.type == CryptoKitty.cooldownIndexTraitName }), let cooldownIndex = Int(cooldown.value) {
            if Constants.cryptoKittiesCooldowns.indices.contains(cooldownIndex) {
                return R.string.localizable.cryptoKittiesCooldown(Constants.cryptoKittiesCooldowns[cooldownIndex])
            } else {
                return R.string.localizable.cryptoKittiesCooldownUnknown()
            }
        } else {
            return ""
        }
    }

    var description: String {
        return tokenHolder.values["description"] as? String ?? ""
    }

    var thumbnailImageUrl: URL? {
        guard let url = tokenHolder.values["thumbnailUrl"] as? String else { return nil }
        return URL(string: url)
    }

    var imageUrl: URL? {
        guard let url = tokenHolder.values["imageUrl"] as? String else { return nil }
        return URL(string: url)
    }

    var externalLink: URL? {
        guard let url = tokenHolder.values["externalLink"] as? String else { return nil }
        return URL(string: url)
    }

    //TODO using CryptoKitty struct here, not good
    var attributes: [CryptoKittyCAttributeCellViewModel] {
        let traits = tokenHolder.values["traits"] as? [CryptoKittyTrait] ?? []
        let withoutGenerationAndCooldownIndex = traits.filter { $0.type != CryptoKitty.generationTraitName && $0.type != CryptoKitty.cooldownIndexTraitName }
        return withoutGenerationAndCooldownIndex.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var areImagesHidden: Bool {
        return tokenHolder.status == .availableButDataUnavailable
    }

    var isDescriptionHidden: Bool {
        return tokenHolder.status == .availableButDataUnavailable
    }

    var urlButtonTextColor: UIColor {
        return UIColor(red: 84, green: 84, blue: 84)
    }

    var urlButtonFont: UIFont {
        return Fonts.semibold(size: 12)!
    }

    var urlButtonImage: UIImage {
        return R.image.cryptoKittyButtonArrow()!
    }

    private func mapTraitsToProperName(name: String, value: String) -> CryptoKittyCAttributeCellViewModel {
        let mapping = [
            "body": "fur",
            "coloreyes": "eye color",
            "eyes": "eye shape",
            "colorprimary": "base color",
            "colorsecondary": "highlight color",
            "colortertiary": "accent color",
            //These map directly:
            "mouth": "mouth",
            "pattern": "pattern",
        ]

        return CryptoKittyCAttributeCellViewModel(name: mapping[name] ?? name, value: value)
    }
}
