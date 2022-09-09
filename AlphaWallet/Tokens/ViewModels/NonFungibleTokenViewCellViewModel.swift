// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct NonFungibleTokenViewCellViewModel {
    private let token: TokenViewModel
    private let isVisible: Bool
    let accessoryType: UITableViewCell.AccessoryType

    init(token: TokenViewModel, isVisible: Bool = true, accessoryType: UITableViewCell.AccessoryType = .none) {
        self.token = token
        self.isVisible = isVisible
        self.accessoryType = accessoryType
    }

    var blockChainNameFont: UIFont {
        return Screen.TokenCard.Font.blockChainName
    }

    var blockChainNameColor: UIColor {
        return Screen.TokenCard.Color.blockChainName
    }

    var blockChainNameBackgroundColor: UIColor {
        return token.server.blockChainNameColor
    }

    var blockChainTag: String {
        return "  \(token.server.name)     "
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainNameCornerRadius: CGFloat {
        return Screen.TokenCard.Metric.blockChainTagCornerRadius
    }

    var blockChainName: String {
        return token.server.blockChainName
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.tableViewCellBackground
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleAttributedString: NSAttributedString {
        return .init(string: token.tokenScriptOverrides?.safeShortTitleInPluralForm ?? "-", attributes: [
            .font: Screen.TokenCard.Font.title,
            .foregroundColor: Screen.TokenCard.Color.title
        ])
    }

    var tickersAmountAttributedString: NSAttributedString {
        return .init(string: "\(token.nonZeroBalance.count.toString()) \(token.symbol)", attributes: [
            .font: Screen.TokenCard.Font.subtitle,
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon(withSize: .s750)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }

}

extension NonFungibleTokenViewCellViewModel: Hashable {
    static func == (lhs: NonFungibleTokenViewCellViewModel, rhs: NonFungibleTokenViewCellViewModel) -> Bool {
        return lhs.token == rhs.token &&
            lhs.token.tokenScriptOverrides?.safeShortTitleInPluralForm == rhs.token.tokenScriptOverrides?.shortTitleInPluralForm &&
            lhs.token.nonZeroBalance.count.toString() == rhs.token.nonZeroBalance.count.toString()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(isVisible)
        hasher.combine(accessoryType)
        hasher.combine(token.contractAddress)
        hasher.combine(token.server)
        hasher.combine(token.tokenScriptOverrides?.safeShortTitleInPluralForm)
        hasher.combine(token.nonZeroBalance.count)
    }
}
