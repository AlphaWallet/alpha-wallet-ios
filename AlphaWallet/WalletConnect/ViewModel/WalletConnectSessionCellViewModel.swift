// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

struct WalletConnectSessionCellViewModel {
    private let session: WalletConnectSession

    init(session: WalletConnectSession) {
        self.session = session
    }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    var nameFont: UIFont {
        Fonts.regular(size: 17)
    }

    var name: String {
        session.dAppInfo.peerMeta.name
    }
}