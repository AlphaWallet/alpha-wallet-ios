//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit

struct WalletConnectToSessionViewModel: SectionProtocol {
    var openedSections: Set<Int> = .init()

    private let sessionProposal: AlphaWallet.WalletConnect.SessionProposal
    private (set) var serversToConnect: [RPCServer]
    private (set) var methods: [String]

    var connectionIconUrl: URL? {
        sessionProposal.iconUrl
    }

    init(sessionProposal: AlphaWallet.WalletConnect.SessionProposal, serversToConnect: [RPCServer]) {
        self.sessionProposal = sessionProposal
        self.serversToConnect = serversToConnect
        self.methods = sessionProposal.methods
    }

    mutating func set(serversToConnect: [RPCServer]) {
        self.serversToConnect = serversToConnect
    }

    var navigationTitle: String {
        return R.string.localizable.walletConnectConnectionTitle()
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var connectionButtonTitle: String {
        return R.string.localizable.confirmPaymentConnectButtonTitle()
    }

    var rejectionButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var sections: [Section] {
        var sections: [Section] = [.name, .url]
        sections += [.networks]
        sections += methods.isEmpty ? [] : [.methods]

        return sections
    }

    enum Section: CaseIterable {
        case name
        case networks
        case methods
        case url

        var title: String {
            switch self {
            case .name:
                return R.string.localizable.walletConnectConnectionNameTitle()
            case .networks:
                return String()
            case .url:
                return R.string.localizable.walletConnectConnectionUrlTitle()
            case .methods:
                return "Methods"
            }
        }

        var isExpandable: Bool {
            switch self {
            case .name, .url:
                return false
            case .methods, .networks:
                return true
            }
        }
    }

    var allowChangeConnectionServer: Bool {
        return sessionProposal.isServerEditingAvailable ?? false
    }

    func isSubviewsHidden(section: Int, row: Int) -> Bool {
        let isOpened = openedSections.contains(section)
        switch sections[section] {
        case .name, .url:
            return true
        case .networks:
            if sessionProposal.isV1SessionProposal {
                return false
            } else {
                return isOpened
            }
        case .methods:
            return isOpened
        }
    }

    private var serversSectionTitle: String {
        if sessionProposal.isV1SessionProposal {
            return R.string.localizable.walletConnectConnectionNetworkTitle()
        } else {
            return R.string.localizable.walletConnectConnectionNetworksTitle()
        }
    }

    func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
        let isOpened = openedSections.contains(section)

        switch sections[section] {
        case .name:
            return .init(title: .normal(sessionProposal.name), headerName: sections[section].title, configuration: .init(section: section))
        case .networks:
            let servers = serversToConnect.map { $0.displayName }.joined(separator: ", ")
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: isOpened, section: section, shouldHideChevron: sessionProposal.isV1SessionProposal)

            return .init(title: .normal(servers), headerName: serversSectionTitle, configuration: configuration)
        case .url:
            let dappUrl = sessionProposal.dappUrl.absoluteString
            return .init(title: .normal(dappUrl), headerName: sections[section].title, configuration: .init(section: section))
        case .methods:
            let methods = methods.joined(separator: ", ")
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: isOpened, section: section, shouldHideChevron: !sections[section].isExpandable)
            return .init(title: .normal(methods), headerName: sections[section].title, configuration: configuration)
        }
    }
}
