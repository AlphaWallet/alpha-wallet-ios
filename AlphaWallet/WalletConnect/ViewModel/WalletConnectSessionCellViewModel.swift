// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct WalletConnectSessionCellViewModel {
    let session: AlphaWallet.WalletConnect.Session
    var servers: [RPCServer] { session.servers }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    var serverIconImages: [Subscribable<Image>] {
        servers.map { $0.walletConnectIconImage }
    }

    var sessionNameAttributedString: NSAttributedString {
        let servers = servers.map { $0.name }.joined(separator: ", ")
        return .init(string: "\(session.dappName) (\(servers))", attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Colors.black
        ])
    }

    var sessionURLAttributedString: NSAttributedString {
        return .init(string: session.dappUrl.absoluteString, attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: R.color.dove()!
        ])
    }

    var sessionIconURL: URL? {
        return session.dappIconUrl
    }
    
}
