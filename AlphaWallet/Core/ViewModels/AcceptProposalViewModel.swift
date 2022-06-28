//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit

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
    private let analyticsCoordinator: AnalyticsCoordinator

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

    init(proposalType: ProposalType, analyticsCoordinator: AnalyticsCoordinator) {
        self.proposalType = proposalType
        self.analyticsCoordinator = analyticsCoordinator
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
            analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logSwitchServer() {
        switch proposalType {
        case .walletConnect:
            analyticsCoordinator.log(navigation: Analytics.Navigation.switchServers, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logCancelServerSelection() {
        switch proposalType {
        case .walletConnect:
            analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        case .deepLink:
            break
        }
    }

    func logConnectToServers() {
        switch proposalType {
        case .walletConnect(let viewModel):
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnect, properties: [
                Analytics.Properties.chains.rawValue: viewModel.serversToConnect.map({ $0.chainID })
            ])
        case .deepLink:
            break
        }
    }

    func logConnectToServersDisabled() {
        switch proposalType {
        case .walletConnect(let viewModel):
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [
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
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [
                Analytics.Properties.chains.rawValue: viewModel.serversToConnect.map({ $0.chainID }),
                Analytics.Properties.reason.rawValue: "Chain Disabled"
            ])
        case .deepLink:
            analyticsCoordinator.log(navigation: Analytics.Navigation.deepLink)
        }
    }

    func logApproveCancelation() {
        analyticsCoordinator.log(action: Analytics.Action.DeepLinkCancel)
    }
}

extension AcceptProposalViewModel {
    enum ViewModelType {
        case header(viewModel: TransactionConfirmationHeaderViewModel, editButtonEnabled: Bool)
        case anyField(viewModel: TransactionConfirmationRowInfoViewModel, isHidden: Bool)
        case serverField(viewModel: TransactionConfirmationRPCServerInfoViewModel, isHidden: Bool)
    }
}
