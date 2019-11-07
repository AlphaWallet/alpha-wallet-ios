// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct EnterSellTokensCardPriceQuantityViewControllerViewModel {
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    let token: TokenObject
    let tokenHolder: TokenHolder
    var ethCost: Ether = .zero
    var dollarCost: String = ""

    var headerTitle: String {
		return R.string.localizable.aWalletTokenSellSelectQuantityTitle()
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var choiceLabelColor: UIColor {
        return Colors.appText
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var quantityLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenSellQuantityTitle(tokenTypeName.localizedUppercase)
    }

    var pricePerTokenLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getName()
        return R.string.localizable.aWalletTokenSellPricePerTokenTitle(tokenTypeName.localizedUppercase)
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle()
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalCostTitle()
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appText
    }

    var ethCostLabelText: String {
        return "\(ethCost.formattedDescription) \(server.symbol)"
    }

    var ethCostLabelColor: UIColor {
        return Colors.appText
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelColor: UIColor {
        return Colors.appText
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var dollarCostLabelText: String {
        return "$\(dollarCost)"
    }

    var dollarCostLabelColor: UIColor {
        return Colors.darkGray
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var dollarCostLabelBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var hideDollarCost: Bool {
        return dollarCost.trimmed.isEmpty
    }

    init(token: TokenObject, tokenHolder: TokenHolder, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }
}
