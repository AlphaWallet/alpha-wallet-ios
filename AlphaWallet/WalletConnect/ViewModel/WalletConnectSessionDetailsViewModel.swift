//
//  SessionDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit 

struct WalletConnectSessionDetailsViewModel {

    private let server: WalletConnectServer
    private var isOnline: Bool {
        server.hasConnected(session: session)
    }

    var navigationTitle: String {
        return R.string.localizable.walletConnectTitle()
    }

    var walletImageIcon: UIImage? {
        return R.image.walletconnect()
    }

    var statusRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectStatusPlaceholder(),
            details: isOnline ? R.string.localizable.walletConnectStatusOnline() : R.string.localizable.walletConnectStatusOffline(),
            detailsLabelFont: Fonts.semibold(size: 17),
            detailsLabelTextColor: isOnline ? R.color.green()! : R.color.danger()!
        )
    }

    var nameRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectSessionName(),
            details: session.dAppInfo.peerMeta.name,
            separatorOptions: .both
        )
    }

    var connectedToRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectSessionConnectedURL(),
            details: session.dAppInfo.peerMeta.url.absoluteString
        )
    }

    var dissconnectButtonText: String {
        return R.string.localizable.walletConnectSessionDisconnect()
    }

    var isDisconnectAvailable: Bool {
        return isOnline
    }

    private let session: WalletConnectSession

    init(server: WalletConnectServer, session: WalletConnectSession) {
        self.server = server
        self.session = session
    }
}
