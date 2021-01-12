// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

struct WalletConnectSessionCellViewModel {
    let session: WalletConnectSession
    let server: RPCServer

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    var nameFont: UIFont {
        Fonts.regular(size: 17)
    }

    var name: String {
        "\(session.dAppInfo.peerMeta.name) (\(server.name))"
    }
}