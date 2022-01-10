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
        return R.string.localizable.walletConnectTitle(preferredLanguages: Languages.preferred())
    }

    var walletImageIcon: UIImage? {
        return R.image.walletConnectIcon()
    }

    var sessionIconURL: URL? {
        session.dappIconUrl
    }

    var statusRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectStatusPlaceholder(preferredLanguages: Languages.preferred()),
            details: isOnline ? R.string.localizable.walletConnectStatusOnline(preferredLanguages: Languages.preferred()) : R.string.localizable.walletConnectStatusOffline(preferredLanguages: Languages.preferred()),
            detailsLabelFont: Fonts.semibold(size: 17),
            detailsLabelTextColor: isOnline ? R.color.green()! : R.color.danger()!,
            hideSeparatorOptions: .none
        )
    }

    var dappNameRowViewModel: WallerConnectRawViewModel {
        return .init(text: R.string.localizable.walletConnectSessionName(preferredLanguages: Languages.preferred()), details: session.dappName, hideSeparatorOptions: .top)
    }

    var dappNameAttributedString: NSAttributedString {
        return .init(string: session.dappNameShort, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Colors.black
        ])
    }

    var dappUrlRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectSessionConnectedURL(preferredLanguages: Languages.preferred()),
            details: session.dAppInfo.peerMeta.url.absoluteString,
            hideSeparatorOptions: .top
        )
    }

    var chainRowViewModel: WallerConnectRawViewModel {
        if let server = server.urlToServer[session.url] {
            return .init(text: R.string.localizable.settingsNetworkButtonTitle(preferredLanguages: Languages.preferred()), details: server.name, hideSeparatorOptions: .top)
        } else {
            // Displays for disconnected session
            return .init(text: R.string.localizable.settingsNetworkButtonTitle(preferredLanguages: Languages.preferred()), details: "-", hideSeparatorOptions: .top)
        }
    }

    var dissconnectButtonText: String {
        return R.string.localizable.walletConnectSessionDisconnect(preferredLanguages: Languages.preferred())
    }

    var switchNetworkButtonText: String {
        return  R.string.localizable.walletConnectSessionSwitchNetwork(preferredLanguages: Languages.preferred())
    }

    var isDisconnectAvailable: Bool {
        return isOnline
    }

    private let session: WalletConnectSession
    var rpcServer: RPCServer? {
        server.urlToServer[session.url]
    }

    init(server: WalletConnectServer, session: WalletConnectSession) {
        self.server = server
        self.session = session
    }
}

