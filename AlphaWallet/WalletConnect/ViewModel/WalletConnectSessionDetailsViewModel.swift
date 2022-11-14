//
//  SessionDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct WalletConnectSessionDetailsViewModelInput {
    let disconnect: AnyPublisher<Void, Never>
}

struct WalletConnectSessionDetailsViewModelOutput {
    let didDisconnect: AnyPublisher<Void, Never>
    let viewState: AnyPublisher<WalletConnectSessionDetailsViewModel.ViewState, Never>
}

class WalletConnectSessionDetailsViewModel {
    @Published private var session: AlphaWallet.WalletConnect.Session
    private let provider: WalletConnectServerProviderType
    private var cancellable = Set<AnyCancellable>()
    private let analytics: AnalyticsLogger
    private let config: Config = Config()
    private var rpcServers: [RPCServer] { session.servers }

    var methods: [String] { session.methods }

    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
    }

    var serversViewModel: ServersViewModel {
        let selectedServers: [RPCServerOrAuto] = rpcServers.map { return .server($0) }
        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        var viewModel = ServersViewModel(servers: servers, selectedServers: selectedServers, displayWarningFooter: false)
        viewModel.multipleSessionSelectionEnabled = session.multipleServersSelection == .enabled

        return viewModel
    }

    init(provider: WalletConnectServerProviderType, session: AlphaWallet.WalletConnect.Session, analytics: AnalyticsLogger) {
        self.provider = provider
        self.analytics = analytics
        self.session = session
    }

    func transform(input: WalletConnectSessionDetailsViewModelInput) -> WalletConnectSessionDetailsViewModelOutput {
        provider.sessions
            .receive(on: RunLoop.main)
            .compactMap { [session] sessions in sessions.first(where: { $0.topicOrUrl == session.topicOrUrl }) }
            .handleEvents(receiveOutput: { self.session = $0 })
            .assign(to: \.session, on: self)
            .store(in: &cancellable)

        let didDisconnect = input.disconnect
            .map { _ in return self.session }
            .handleEvents(receiveOutput: { [analytics, provider] session in
                analytics.log(action: Analytics.Action.walletConnectDisconnect)

                try? provider.disconnect(session.topicOrUrl)
            }).mapToVoid()
            .eraseToAnyPublisher()

        let viewState = $session
            .map { [provider] session -> WalletConnectSessionDetailsViewModel.ViewState in
                let statusRowViewModel = self.statusRowViewModel(session: session)
                let dappNameRowViewModel = self.dappNameRowViewModel(session: session)
                let chainRowViewModel = self.chainRowViewModel(session: session)
                let methodsRowViewModel = self.methodsRowViewModel(session: session)
                let isConnected = provider.isConnected(session.topicOrUrl)
                let dappNameAttributedString = self.dappNameAttributedString(session: session)
                let dappUrlRowViewModel = self.dappUrlRowViewModel(session: session)

                return WalletConnectSessionDetailsViewModel.ViewState(sessionIconURL: session.dappIconUrl, statusRowViewModel: statusRowViewModel, dappNameRowViewModel: dappNameRowViewModel, dappUrlRowViewModel: dappUrlRowViewModel, chainRowViewModel: chainRowViewModel, methodsRowViewModel: methodsRowViewModel, isDisconnectEnabled: isConnected, isSwitchServerEnabled: isConnected, dappNameAttributedString: dappNameAttributedString)
            }.eraseToAnyPublisher()

        return .init(didDisconnect: didDisconnect, viewState: viewState)
    }

    private func statusRowViewModel(session: AlphaWallet.WalletConnect.Session) -> WallerConnectRowViewModel {
        return .init(
            text: R.string.localizable.walletConnectStatusPlaceholder(),
            details: provider.isConnected(session.topicOrUrl) ? R.string.localizable.walletConnectStatusOnline() : R.string.localizable.walletConnectStatusOffline(),
            detailsLabelFont: Fonts.semibold(size: 17),
            detailsLabelTextColor: provider.isConnected(session.topicOrUrl) ? R.color.green()! : R.color.danger()!,
            hideSeparatorOptions: .none
        )
    }

    private func dappNameRowViewModel(session: AlphaWallet.WalletConnect.Session) -> WallerConnectRowViewModel {
        return .init(text: R.string.localizable.walletConnectDappName(), details: session.dappName, hideSeparatorOptions: .top)
    }

    private func dappNameAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        return .init(string: session.dappNameShort, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Colors.black
        ])
    }

    private func dappUrlRowViewModel(session: AlphaWallet.WalletConnect.Session) -> WallerConnectRowViewModel {
        return .init(
            text: R.string.localizable.walletConnectSessionConnectedURL(),
            details: session.dappUrl.absoluteString,
            hideSeparatorOptions: .top
        )
    }

    private func chainRowViewModel(session: AlphaWallet.WalletConnect.Session) -> WallerConnectRowViewModel {
        let servers = session.servers.map { $0.name }.joined(separator: ", ")
        return .init(text: R.string.localizable.settingsNetworkButtonTitle(), details: servers, hideSeparatorOptions: .top)
    }

    private func methodsRowViewModel(session: AlphaWallet.WalletConnect.Session) -> WallerConnectRowViewModel {
        let servers = session.methods.joined(separator: ", ")
        return .init(text: R.string.localizable.walletConnectConnectionMethodsTitle(), details: servers, hideSeparatorOptions: .top)
    }
}

extension WalletConnectSessionDetailsViewModel {
    struct ViewState {
        let dissconnectButtonText: String = R.string.localizable.walletConnectSessionDisconnect()
        let changeNetworksButtonText: String = R.string.localizable.walletConnectSessionSwitchNetwork()
        let title: String = R.string.localizable.walletConnectTitle()
        let walletImageIcon: UIImage? = R.image.walletConnectIcon()
        let sessionIconURL: URL?
        let statusRowViewModel: WallerConnectRowViewModel
        let dappNameRowViewModel: WallerConnectRowViewModel
        let dappUrlRowViewModel: WallerConnectRowViewModel
        let chainRowViewModel: WallerConnectRowViewModel
        let methodsRowViewModel: WallerConnectRowViewModel
        let isDisconnectEnabled: Bool
        let isSwitchServerEnabled: Bool
        let dappNameAttributedString: NSAttributedString
    }
}
