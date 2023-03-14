// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct GenerateSellMagicLinkViewModel {
    private let keystore: Keystore
    private let session: WalletSession
    private let magicLinkData: MagicLinkGenerator.MagicLinkData
    private let ethCost: Double
    private let linkExpiryDate: Date

    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }
    var subtitleColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }
    var subtitleFont: UIFont {
        return Fonts.regular(size: 25)
    }
    var subtitleLabelText: String {
        return R.string.localizable.aWalletTokenSellConfirmSubtitle()
    }

    var headerTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmTitle()
    }

    var actionButtonTitleColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }
    var actionButtonBackgroundColor: UIColor {
        return Configuration.Color.Semantic.actionButtonBackground
    }
    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }
    var cancelButtonTitleColor: UIColor {
        return Configuration.Color.Semantic.cancelButtonTitle
    }
    var cancelButtonBackgroundColor: UIColor {
        return .clear
    }
    var cancelButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }
    var actionButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmButtonTitle()
    }
    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmCancelButtonTitle()
    }

    var tokenSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var tokenSaleDetailsLabelColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenSellConfirmExpiryDateDescription(linkExpiryDate.format("dd MMM yyyy  hh:mm"))
    }

    var tokenCountLabelText: String {
        if magicLinkData.count == 1 {

            let tokenTypeName = session.tokenAdaptor.xmlHandler(contract: magicLinkData.contractAddress, tokenType: magicLinkData.tokenType).getLabel()
            return R.string.localizable.aWalletTokenSellConfirmSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = session.tokenAdaptor.xmlHandler(contract: magicLinkData.contractAddress, tokenType: magicLinkData.tokenType).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellConfirmMultipleTokenSelectedTitle(magicLinkData.count, tokenTypeName)
        }
    }

    var perTokenPriceLabelText: String {
        let tokenTypeName = session.tokenAdaptor.xmlHandler(contract: magicLinkData.contractAddress, tokenType: magicLinkData.tokenType).getLabel()
        let amount = NumberFormatter.shortCrypto.string(
            double: ethCost / Double(magicLinkData.count),
            minimumFractionDigits: 4,
            maximumFractionDigits: 8).droppedTrailingZeros

        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount, session.server.symbol, tokenTypeName)
    }

    var totalEthLabelText: String {
        let amount = NumberFormatter.shortCrypto.string(
            double: ethCost,
            minimumFractionDigits: 4,
            maximumFractionDigits: 8).droppedTrailingZeros

        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(amount, session.server.symbol)
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    init(magicLinkData: MagicLinkGenerator.MagicLinkData,
         ethCost: Double,
         linkExpiryDate: Date,
         keystore: Keystore,
         session: WalletSession) {

        self.magicLinkData = magicLinkData
        self.ethCost = ethCost
        self.linkExpiryDate = linkExpiryDate
        self.session = session
        self.keystore = keystore
    }

    func generateSellLink() async throws -> String {
        return try await MagicLinkGenerator(
            keystore: keystore,
            session: session,
            prompt: R.string.localizable.keystoreAccessKeySign()).generateSellLink(
                magicLinkData: magicLinkData,
                linkExpiryDate: linkExpiryDate,
                ethCost: ethCost)
    }

}
