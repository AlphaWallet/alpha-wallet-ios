// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct NonFungibleTokenViewCellViewModel {
    private let token: Token
    private let assetDefinitionStore: AssetDefinitionStore
    private let isVisible: Bool
    private let eventsDataStore: NonActivityEventsDataStore
    private let wallet: Wallet
    let accessoryType: UITableViewCell.AccessoryType

    init(token: Token, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, wallet: Wallet, isVisible: Bool = true, accessoryType: UITableViewCell.AccessoryType = .none) {
        self.eventsDataStore = eventsDataStore
        self.wallet = wallet
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.isVisible = isVisible
        self.accessoryType = accessoryType
    }

    private var amount: String {
        let actualBalance = token.nonZeroBalance
        return actualBalance.count.toString()
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
        return Screen.TokenCard.Color.background
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleAttributedString: NSAttributedString {
        let title = token.shortTitleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
        return .init(string: title, attributes: [
            .font: Screen.TokenCard.Font.title,
            .foregroundColor: Screen.TokenCard.Color.title
        ])
    }

    var tickersAmountAttributedString: NSAttributedString {
        return .init(string: "\(amount) \(token.symbol)", attributes: [
            .font: Screen.TokenCard.Font.subtitle,
            .foregroundColor: Screen.TokenCard.Color.subtitle
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
