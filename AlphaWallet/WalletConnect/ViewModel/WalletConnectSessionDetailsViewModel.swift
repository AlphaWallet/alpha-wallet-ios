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
    let copyToClipboard: AnyPublisher<Void, Never>
    let disconnect: AnyPublisher<Void, Never>
}

struct WalletConnectSessionDetailsViewModelOutput {
    let didDisconnect: AnyPublisher<Void, Never>
    let viewState: AnyPublisher<WalletConnectSessionDetailsViewModel.ViewState, Never>
    let copiedToClipboard: AnyPublisher<String, Never>
}

class WalletConnectSessionDetailsViewModel {
    @Published private var session: AlphaWallet.WalletConnect.Session
    private let walletConnectProvider: WalletConnectProvider
    private var cancellable = Set<AnyCancellable>()
    private let analytics: AnalyticsLogger
    private let serversProvider: ServersProvidable
    private var rpcServers: [RPCServer] { session.servers }
    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { serversProvider.enabledServers.contains($0) }
    }

    var serversViewModel: ServersViewModel {
        let selectedServers: [RPCServerOrAuto] = rpcServers.map { return .server($0) }
        let servers = serverChoices.filter { serversProvider.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        var viewModel = ServersViewModel(servers: servers, selectedServers: selectedServers, displayWarningFooter: false)
        viewModel.multipleSessionSelectionEnabled = session.multipleServersSelection == .enabled

        return viewModel
    }

    init(walletConnectProvider: WalletConnectProvider,
         session: AlphaWallet.WalletConnect.Session,
         analytics: AnalyticsLogger,
         serversProvider: ServersProvidable) {

        self.serversProvider = serversProvider
        self.walletConnectProvider = walletConnectProvider
        self.analytics = analytics
        self.session = session
    }

    func transform(input: WalletConnectSessionDetailsViewModelInput) -> WalletConnectSessionDetailsViewModelOutput {
        walletConnectProvider.sessionsPublisher
            .receive(on: RunLoop.main)
            .compactMap { [session] sessions in sessions.first(where: { $0.topicOrUrl == session.topicOrUrl }) }
            .handleEvents(receiveOutput: { self.session = $0 })
            .assign(to: \.session, on: self)
            .store(in: &cancellable)

        let didDisconnect = input.disconnect
            .map { _ in return self.session }
            .handleEvents(receiveOutput: { [analytics, walletConnectProvider] session in
                analytics.log(action: Analytics.Action.walletConnectDisconnect)

                try? walletConnectProvider.disconnect(session.topicOrUrl)
            }).mapToVoid()
            .eraseToAnyPublisher()

        let copiedToClipboard = copyToClipboard(trigger: input.copyToClipboard)

        let viewState = $session
            .map { [walletConnectProvider] session -> WalletConnectSessionDetailsViewModel.ViewState in
                let isConnected = walletConnectProvider.isConnected(session.topicOrUrl)

                return WalletConnectSessionDetailsViewModel.ViewState(
                    sessionIconURL: session.dappIconUrl,
                    statusFieldAttributedString: self.statusFieldAttributedString(session: session),
                    dappNameFieldAttributedString: self.dappNameFieldAttributedString(session: session),
                    dappUrlFieldAttributedString: self.dappUrlFieldAttributedString(session: session),
                    chainFieldAttributedString: self.chainIdFieldAttributedString(session: session),
                    methodsFieldAttributedString: self.methodsFieldAttributedString(session: session),
                    eventsFieldAttributedString: self.eventsFieldAttributedString(session: session),
                    isDisconnectEnabled: isConnected,
                    isSwitchServerEnabled: isConnected,
                    dappNameAttributedString: self.dappNameAttributedString(session: session),
                    viewTypes: self.buildViewTypes(session: session))
            }.eraseToAnyPublisher()

        return .init(
            didDisconnect: didDisconnect,
            viewState: viewState,
            copiedToClipboard: copiedToClipboard)
    }

    private func copyToClipboard(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<String, Never> {
        trigger.map { _ -> String in
            UIPasteboard.general.string = self.session.dappUrl.absoluteString
            return R.string.localizable.copiedToClipboardTitle(R.string.localizable.url())
        }.eraseToAnyPublisher()
    }

    private func buildViewTypes(session: AlphaWallet.WalletConnect.Session) -> [WalletConnectSessionDetailsViewModel.ViewType] {
        var subviews: [WalletConnectSessionDetailsViewModel.ViewType] = [
            .image,
            .separator,
            .status,
            .status,
            .dappName,
            .dappUrl,
            .network
        ]

        if !session.methods.isEmpty {
            subviews += [.methods]
        }

        if !session.events.isEmpty {
            subviews += [.events]
        }
        return subviews
    }

    private func statusFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        NSAttributedString(string: walletConnectProvider.isConnected(session.topicOrUrl) ? R.string.localizable.walletConnectStatusOnline() : R.string.localizable.walletConnectStatusOffline(), attributes: [
            .font: Fonts.semibold(size: 17),
            .foregroundColor: walletConnectProvider.isConnected(session.topicOrUrl) ? Configuration.Color.Semantic.pass : Configuration.Color.Semantic.fail
        ])
    }

    private func dappNameFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        let dappName = session.dappName.trimmed.isEmpty ? "--" : session.dappName.trimmed
        return NSAttributedString(string: dappName, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    private func dappNameAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        let dappName = session.dappNameShort.trimmed.isEmpty ? "--" : session.dappNameShort.trimmed
        return .init(string: dappName, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    private func dappUrlFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        return NSAttributedString(string: session.dappUrl.absoluteString, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    private func chainIdFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        let servers = session.servers.map { $0.name }.joined(separator: ", ")
        return NSAttributedString(string: servers, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    private func methodsFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        let methods = session.methods.joined(separator: ", ")
        return NSAttributedString(string: methods, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    private func eventsFieldAttributedString(session: AlphaWallet.WalletConnect.Session) -> NSAttributedString {
        let events = session.events.joined(separator: ", ")
        return NSAttributedString(string: events, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }
}

extension WalletConnectSessionDetailsViewModel {
    enum ViewType: String, Hashable {
        case separator
        case image
        case status
        case dappName
        case dappUrl
        case network
        case methods
        case events
    }

    struct ViewState {
        let dissconnectButtonText: String = R.string.localizable.walletConnectSessionDisconnect()
        let changeNetworksButtonText: String = R.string.localizable.walletConnectSessionSwitchNetwork()
        let title: String = R.string.localizable.walletConnectTitle()
        let walletImageIcon: UIImage? = R.image.walletConnectIcon()
        let sessionIconURL: URL?
        let statusFieldAttributedString: NSAttributedString
        let dappNameFieldAttributedString: NSAttributedString
        let dappUrlFieldAttributedString: NSAttributedString
        let chainFieldAttributedString: NSAttributedString
        let methodsFieldAttributedString: NSAttributedString
        let eventsFieldAttributedString: NSAttributedString
        let isDisconnectEnabled: Bool
        let isSwitchServerEnabled: Bool
        let dappNameAttributedString: NSAttributedString
        let viewTypes: [WalletConnectSessionDetailsViewModel.ViewType]
    }
}
