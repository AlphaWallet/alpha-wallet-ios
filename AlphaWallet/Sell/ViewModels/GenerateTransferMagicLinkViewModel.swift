// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct GenerateTransferMagicLinkViewModel {
    private let magicLinkData: MagicLinkGenerator.MagicLinkData
    private let linkExpiryDate: Date
    private let assetDefinitionStore: AssetDefinitionStore
    private let keystore: Keystore
    private let session: WalletSession

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
        return R.string.localizable.aWalletTokenTransferConfirmSubtitle()
    }

    var headerTitle: String {
        return R.string.localizable.aWalletTokenTransferConfirmTitle()
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
            let tokenTypeName = assetDefinitionStore.xmlHandler(forContract: magicLinkData.contractAddress, tokenType: magicLinkData.tokenType).getLabel()
            return R.string.localizable.aWalletTokenSellConfirmSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = assetDefinitionStore.xmlHandler(forContract: magicLinkData.contractAddress, tokenType: magicLinkData.tokenType).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellConfirmMultipleTokenSelectedTitle(magicLinkData.count, tokenTypeName)
        }
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    init(magicLinkData: MagicLinkGenerator.MagicLinkData,
         linkExpiryDate: Date,
         assetDefinitionStore: AssetDefinitionStore,
         keystore: Keystore,
         session: WalletSession) {

        self.session = session
        self.keystore = keystore
        self.magicLinkData = magicLinkData
        self.linkExpiryDate = linkExpiryDate
        self.assetDefinitionStore = assetDefinitionStore
    }

    func generateTransferLink() async throws -> String {
        return try await MagicLinkGenerator(
            keystore: keystore,
            session: session,
            prompt: R.string.localizable.keystoreAccessKeySign()).generateTransferLink(
                magicLinkData: magicLinkData,
                linkExpiryDate: linkExpiryDate)
    }
}
