// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import BigInt

struct EnterSellTokensCardPriceQuantityViewModel {
    let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let currencyService: CurrencyService
    lazy var ethToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)

    let token: Token
    let tokenHolder: TokenHolder
    var ethCost: Double = .zero
    var dollarCost: String = ""

    var headerTitle: String {
        return R.string.localizable.aWalletTokenSellSelectQuantityTitle()
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var quantityLabelText: String {
        let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token).getNameInPluralForm()
        return R.string.localizable.aWalletTokenSellQuantityTitle(tokenTypeName.localizedUppercase)
    }

    var pricePerTokenLabelText: String {
        let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token).getLabel()
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

    var ethCostLabelText: String {
        let amount = NumberFormatter.shortCrypto.string(double: ethCost, minimumFractionDigits: 6, maximumFractionDigits: 8).droppedTrailingZeros
        return "\(amount) \(session.server.symbol)"
    }

    var dollarCostLabelText: String {
        return "\(currencyService.currency.symbol)\(dollarCost)"
    }

    var hideDollarCost: Bool {
        return dollarCost.trimmed.isEmpty
    }

    init(token: Token,
         tokenHolder: TokenHolder,
         session: WalletSession,
         assetDefinitionStore: AssetDefinitionStore,
         currencyService: CurrencyService) {

        self.token = token
        self.currencyService = currencyService
        self.tokenHolder = tokenHolder
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
    }
}
