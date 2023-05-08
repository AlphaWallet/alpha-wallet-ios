// Copyright © 2018 Stormbird PTE. LTD.

import AlphaWalletFoundation
import Foundation
import UIKit

struct ChooseTokenCardTransferModeViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let session: WalletSession

    var headerTitle: String {
        let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getNameInPluralForm()

        return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }
}
