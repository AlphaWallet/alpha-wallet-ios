//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit

struct WalletConnectToSessionViewModel {

    private let connection: WalletConnectConnection
    private var serverToConnect: RPCServer

    var connectionIconUrl: URL? {
        connection.iconUrl
    }

    init(connection: WalletConnectConnection, serverToConnect: RPCServer) {
        self.connection = connection
        self.serverToConnect = serverToConnect
    }

    mutating func set(serverToConnect: RPCServer) {
        self.serverToConnect = serverToConnect
    }

    var navigationTitle: String {
        return R.string.localizable.walletConnectConnectionTitle(preferredLanguages: Languages.preferred())
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle(preferredLanguages: Languages.preferred())
    }

    var connectionButtonTitle: String {
        return R.string.localizable.confirmPaymentConnectButtonTitle(preferredLanguages: Languages.preferred())
    }

    var rejectionButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle(preferredLanguages: Languages.preferred())
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var sections: [Section] {
        Section.allCases
    }

    enum Section: CaseIterable {
        case name
        case network
        case url

        var title: String {
            switch self {
            case .name:
                return R.string.localizable.walletConnectConnectionNameTitle(preferredLanguages: Languages.preferred())
            case .network:
                return R.string.localizable.walletConnectConnectionNetworkTitle(preferredLanguages: Languages.preferred())
            case .url:
                return R.string.localizable.walletConnectConnectionUrlTitle(preferredLanguages: Languages.preferred())
            }
        }
    }

    var allowChangeConnectionServer: Bool {
        return connection.server == nil
    }

    func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
        switch sections[section] {
        case .name:
            return .init(title: .normal(connection.name), headerName: sections[section].title, configuration: .init(section: section))
        case .network:
            return .init(title: .normal(serverToConnect.displayName), headerName: sections[section].title, configuration: .init(section: section))
        case .url:
            return .init(title: .normal(connection.dappUrl.absoluteString), headerName: sections[section].title, configuration: .init(section: section))
        }
    }
}
