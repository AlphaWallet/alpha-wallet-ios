//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit
import AlphaWalletFoundation

enum ProposalType {
    case walletConnect(AcceptWalletConnectSessionViewModel)
    case deepLink(AcceptDeepLinkViewModel)
}

enum ProposalResult {
    case walletConnect(RPCServer)
    case deepLink
    case cancel
}

class AcceptProposalViewModel: NSObject {
    private let analytics: AnalyticsLogger

    let proposalType: ProposalType

    var navigationTitle: String {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.navigationTitle
        case .deepLink(let viewModel):
            return viewModel.navigationTitle
        }
    }

    var connectButtonTitle: String {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.connectButtonTitle
        case .deepLink(let viewModel):
            return viewModel.connectButtonTitle
        }
    }

    var rejectButtonTitle: String {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.rejectButtonTitle
        case .deepLink(let viewModel):
            return viewModel.rejectButtonTitle
        }
    }

    var backgroundColor: UIColor = Colors.clear
    var footerBackgroundColor: UIColor = Colors.appWhite

    var connectionIconUrl: URL? {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.connectionIconUrl
        case .deepLink(let viewModel):
            return viewModel.connectionIconUrl
        }
    }

    var viewModels: [ViewModelType] {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.viewModels
        case .deepLink(let viewModel):
            return viewModel.viewModels
        }
    }

    init(proposalType: ProposalType, analytics: AnalyticsLogger) {
        self.proposalType = proposalType
        self.analytics = analytics
        super.init()
    }

    func isSubviewsHidden(section: Int, row: Int) -> Bool {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.isSubviewsHidden(section: section, row: row)
        case .deepLink(let viewModel):
            return viewModel.isSubviewsHidden(section: section, row: row)
        }
    }

    func showHideSection(_ section: Int) -> TransactionConfirmationViewModel.Action {
        switch proposalType {
        case .walletConnect(let viewModel):
            return viewModel.showHideSection(section)
        case .deepLink(let viewModel):
            return viewModel.showHideSection(section)
        }
    }

    func logServerSelected() {
        switch proposalType {
        case .walletConnect:
            analytics.log(action: Analytics.Action.switchedServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logSwitchServer() {
        switch proposalType {
        case .walletConnect:
            analytics.log(navigation: Analytics.Navigation.switchServers, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logCancelServerSelection() {
        switch proposalType {
        case .walletConnect:
            analytics.log(action: Analytics.Action.cancelsSwitchServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logConnectToServers() {
        switch proposalType {
        case .walletConnect(let viewModel):
            analytics.log(action: Analytics.Action.walletConnectConnect, properties: [
                Analytics.Properties.chains.rawValue: viewModel.serversToConnect.map({ $0.chainID })
            ])
        case .deepLink:
            break
        }
    }

    func logConnectToServersDisabled() {
        switch proposalType {
        case .walletConnect(let viewModel):
            analytics.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [
                Analytics.Properties.chains.rawValue: viewModel.serversToConnect.map({ $0.chainID }),
                Analytics.Properties.reason.rawValue: "Chain Disabled"
            ])
        case .deepLink:
            break
        }
    }

    func logStart() {
        switch proposalType {
        case .walletConnect(let viewModel):
            analytics.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [
                Analytics.Properties.chains.rawValue: viewModel.serversToConnect.map({ $0.chainID }),
                Analytics.Properties.reason.rawValue: "Chain Disabled"
            ])
        case .deepLink:
            analytics.log(navigation: Analytics.Navigation.deepLink)
        }
    }

    func logApproveCancelation() {
        analytics.log(action: Analytics.Action.deepLinkCancel)
    }
}

extension AcceptProposalViewModel {
    enum ViewModelType {
        case header(viewModel: TransactionConfirmationHeaderViewModel, editButtonEnabled: Bool)
        case anyField(viewModel: TransactionConfirmationRowInfoViewModel, isHidden: Bool)
        case serverField(viewModel: TransactionConfirmationRPCServerInfoViewModel, isHidden: Bool)
    }
}
