// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenViewModel

    var assetsCountAttributedString: NSAttributedString {
        return .init(string: "\(token.nonZeroBalance.count.toString()) \(token.symbol)", attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: R.color.dove()!
        ])
    }

    var titleAttributedString: NSAttributedString {
        return .init(string: token.tokenScriptOverrides?.titleInPluralForm ?? "", attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Colors.appText
        ])
    }
    var tokenIcon: Subscribable<TokenImage> {
        token.icon(withSize: .s750)
    }

    init(token: TokenViewModel) {
        self.token = token 
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.nftBox
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
        hasher.combine(token.tokenScriptOverrides?.titleInPluralForm)
        hasher.combine(token.nonZeroBalance)
    }
}
