// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct NonFungibleTokenViewCellViewModel {
    private let safeShortTitleInPluralForm: String
    private let symbol: String
    private let server: RPCServer
    private let contract: AlphaWallet.Address
    private let nonZeroBalanceCount: Int
    private let isVisible: Bool

    let iconImage: Subscribable<TokenImage>
    let accessoryType: UITableViewCell.AccessoryType

    init(token: TokenViewModel, isVisible: Bool = true, accessoryType: UITableViewCell.AccessoryType = .none) {
        self.contract = token.contractAddress
        self.server = token.server
        self.iconImage = token.icon(withSize: .s750)
        self.nonZeroBalanceCount = token.nonZeroBalance.count
        self.symbol = token.symbol
        self.safeShortTitleInPluralForm = token.tokenScriptOverrides?.safeShortTitleInPluralForm ?? ""
        self.isVisible = isVisible
        self.accessoryType = accessoryType
    }

    var contentsCornerRadius: CGFloat {
        return DataEntry.Metric.CornerRadius.box
    }

    var titleAttributedString: NSAttributedString {
        return .init(string: safeShortTitleInPluralForm, attributes: [
            .font: Screen.TokenCard.Font.title,
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    var tickersAmountAttributedString: NSAttributedString {
        return .init(string: "\(nonZeroBalanceCount) \(symbol)", attributes: [
            .font: Screen.TokenCard.Font.subtitle,
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: server)
    }

}

extension NonFungibleTokenViewCellViewModel: Hashable { }
