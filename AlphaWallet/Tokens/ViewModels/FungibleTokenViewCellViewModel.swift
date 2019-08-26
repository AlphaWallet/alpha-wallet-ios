// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct FungibleTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    init(token: TokenObject, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }

    var title: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
    }

    var issuer: String {
        return ""
    }

    var blockChainNameFont: UIFont {
        return Fonts.semibold(size: 12)!
    }

    var blockChainNameColor: UIColor {
        return Colors.appWhite
    }

    var blockChainNameBackgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainTag: String {
        return "  \(server.name)     "
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainName: String {
        return server.blockChainName
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.light(size: 22)!
        } else {
            return Fonts.light(size: 25)!
        }
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }

    var cellHeight: CGFloat {
        return 98
    }
}
