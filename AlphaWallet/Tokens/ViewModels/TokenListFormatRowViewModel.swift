// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenListFormatRowViewModel {
    let tokenHolder: TokenHolder

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var countColor: UIColor {
        return Colors.appHighlightGreen
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var tokenCountFont: UIFont {
        return Fonts.bold(size: 21)!
    }

    var titleFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var descriptionFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var stateBackgroundColor: UIColor {
        return UIColor(red: 151, green: 151, blue: 151)
    }

    var stateColor: UIColor {
        return .white
    }

    var subtitleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 12)!
        } else {
            return Fonts.semibold(size: 15)!
        }
    }

    var detailsFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var urlButtonColor: UIColor {
        return Colors.appText
    }

    var urlButtonFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var urlButtonText: String {
        return R.string.localizable.openSeaNonFungibleTokensUrlOpen(tokenHolder.name)
    }

    var tokenCount: String {
        return "x\(tokenHolder.count)"
    }

    var title: String {
        let tokenId = tokenHolder.values["tokenId"]?.stringValue  ?? ""
        return "\(tokenHolder.name) #\(tokenId)"
    }

    var subtitle: String {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let generationText: String
        let cooldownText: String
        if let generation = traits.first(where: { $0.type == OpenSeaNonFungible.generationTraitName }) {
            generationText = "Gen \(generation.value)"
        } else {
            generationText = ""
        }
        if let cooldown = traits.first(where: { $0.type == OpenSeaNonFungible.cooldownIndexTraitName }) {
            cooldownText = "\(cooldown) Cooldown"
        } else {
            cooldownText = ""
        }
        if generationText.isEmpty {
            return cooldownText
        } else if cooldownText.isEmpty {
            return generationText
        } else {
            return "\(generationText) . \(cooldownText)"
        }
    }

    var description: String {
        return tokenHolder.values["description"]?.stringValue ?? ""
    }

    var thumbnailImageUrl: URL? {
        guard let url = tokenHolder.values["thumbnailUrl"]?.stringValue else { return nil }
        return URL(string: url)
    }

    var externalLink: URL? {
        guard let url = tokenHolder.values["externalLink"]?.stringValue else { return nil }
        return URL(string: url)
    }

    //TODO using CryptoKitty struct here, not good
    var details: [String] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let withoutGenerationAndCooldownIndex = traits.filter { $0.type != OpenSeaNonFungible.generationTraitName && $0.type != OpenSeaNonFungible.cooldownIndexTraitName }
        return withoutGenerationAndCooldownIndex.map { "\($0.type): \($0.value)" }
    }
}
