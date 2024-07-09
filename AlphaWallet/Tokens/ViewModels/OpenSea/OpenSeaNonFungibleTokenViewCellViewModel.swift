// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import Foundation
import UIKit

import AlphaWalletFoundation

struct OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenViewModel

    var assetsCountAttributedString: NSAttributedString {
        return .init(string: "\(token.nonZeroBalance.count.toString()) \(token.symbol)", attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
        ])
    }

    var titleAttributedString: NSAttributedString {
        return .init(string: token.tokenScriptOverrides?.titleInPluralForm ?? token.name, attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
        ])
    }
    let tokenIcon: TokenImagePublisher

    init(token: TokenViewModel,
         tokenImageFetcher: TokenImageFetcher) {
        self.token = token
        self.tokenIcon = tokenImageFetcher.image(token: token, size: .s750)
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.collectionViewBackground
    }

    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var contentsCornerRadius: CGFloat {
        return DataEntry.Metric.CornerRadius.nftBox
    }
}

extension OpenSeaNonFungibleTokenViewCellViewModel: Hashable {
    static func == (lhs: OpenSeaNonFungibleTokenViewCellViewModel, rhs: OpenSeaNonFungibleTokenViewCellViewModel) -> Bool {
        return lhs.token == rhs.token &&
            lhs.token.nonZeroBalance == rhs.token.nonZeroBalance &&
            lhs.token.tokenScriptOverrides?.titleInPluralForm == rhs.token.tokenScriptOverrides?.titleInPluralForm
    }

    //NOTE: We must make sure view models are queal and have same hash value, othervise diffable datasource will cause crash
    func hash(into hasher: inout Hasher) {
        hasher.combine(token.contractAddress)
        hasher.combine(token.server)
        hasher.combine(token.tokenScriptOverrides?.titleInPluralForm ?? token.name)
        hasher.combine(token.nonZeroBalance)
    }
}
