// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenListFormatRowViewModel {
    var ticketHolder: TokenHolder

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

    var ticketCountFont: UIFont {
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
        return R.string.localizable.cryptoKittiesUrlOpen()
    }

    var ticketCount: String {
        return "x\(ticketHolder.tickets.count)"
    }

    var title: String {
        let tokenId = ticketHolder.values["tokenId"] as? String ?? ""
        return R.string.localizable.cryptoKittiesCatName(tokenId)
    }

    var subtitle: String {
        let traits =  ticketHolder.values["traits"] as? [CryptoKittyTrait] ?? []
        let generationText: String
        let cooldownText: String
        if let generation = traits.first(where: { $0.type == "generation" }) {
            generationText = "Gen \(generation.value)"
        } else {
            generationText = ""
        }
        if let cooldown = traits.first(where: { $0.type == "cooldown_index" }), let cooldownIndex = Int(cooldown.value) {
            let cooldownValue = Constants.cryptoKittiesCooldowns[cooldownIndex]
            cooldownText = "\(cooldownValue) Cooldown"
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
        return ticketHolder.values["description"] as? String ?? ""
    }

    var thumbnailImageUrl: URL? {
        guard let url = ticketHolder.values["thumbnailUrl"] as? String else { return nil }
        return URL(string: url)
    }

    var externalLink: URL? {
        guard let url = ticketHolder.values["externalLink"] as? String else { return nil }
        return URL(string: url)
    }

    //TODO using CryptoKitty struct here, not good
    var details: [String] {
        let traits =  ticketHolder.values["traits"] as? [CryptoKittyTrait] ?? []
        let withoutGenerationAndCooldownIndex = traits.filter { $0.type != "generation" && $0.type != "cooldown_index" }
        return withoutGenerationAndCooldownIndex.map { "\($0.type): \($0.value)" }
    }
}
