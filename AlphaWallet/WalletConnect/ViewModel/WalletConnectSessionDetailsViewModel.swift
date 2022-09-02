//
//  SessionDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import AlphaWalletFoundation

struct WalletConnectSessionDetailsViewModel {

    private let provider: WalletConnectServerProviderType
    private var isOnline: Bool {
        provider.isConnected(session.topicOrUrl)
    }

    var navigationTitle: String {
        return R.string.localizable.walletConnectTitle()
    }

    var walletImageIcon: UIImage? {
        return R.image.walletConnectIcon()
    }

    var sessionIconURL: URL? {
        session.dappIconUrl
    }

    var statusRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectStatusPlaceholder(),
            details: isOnline ? R.string.localizable.walletConnectStatusOnline() : R.string.localizable.walletConnectStatusOffline(),
            detailsLabelFont: Fonts.semibold(size: 17),
            detailsLabelTextColor: isOnline ? R.color.green()! : R.color.danger()!,
            hideSeparatorOptions: .none
        )
    }

    var dappNameRowViewModel: WallerConnectRawViewModel {
        return .init(text: R.string.localizable.walletConnectDappName(), details: session.dappName, hideSeparatorOptions: .top)
    }

    var dappNameAttributedString: NSAttributedString {
        return .init(string: session.dappNameShort, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Colors.black
        ])
    }

    var dappUrlRowViewModel: WallerConnectRawViewModel {
        return .init(
            text: R.string.localizable.walletConnectSessionConnectedURL(),
            details: session.dappUrl.absoluteString,
            hideSeparatorOptions: .top
        )
    }

    var chainRowViewModel: WallerConnectRawViewModel {
        let servers = rpcServers.map { $0.name }.joined(separator: ", ")
        return .init(text: R.string.localizable.settingsNetworkButtonTitle(), details: servers, hideSeparatorOptions: .top)
    }

    var methodsRowViewModel: WallerConnectRawViewModel {
        let servers = methods.joined(separator: ", ")
        return .init(text: R.string.localizable.walletConnectConnectionMethodsTitle(), details: servers, hideSeparatorOptions: .top)
    }

    var dissconnectButtonText: String {
        return R.string.localizable.walletConnectSessionDisconnect()
    }

    var switchNetworkButtonText: String {
        return R.string.localizable.walletConnectSessionSwitchNetwork()
    }

    var isDisconnectAvailable: Bool {
        return isOnline
    }

    var isSwitchServerEnabled: Bool {
        isDisconnectAvailable
    }

    private let session: AlphaWallet.WalletConnect.Session
    var topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl {
        session.topicOrUrl
    }
    let rpcServers: [RPCServer]
    let methods: [String]

    init(provider: WalletConnectServerProviderType, session: AlphaWallet.WalletConnect.Session) {
        self.provider = provider
        self.session = session
        self.rpcServers = session.servers
        self.methods = session.methods
    }
}

