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

    init(connection: WalletConnectConnection, serverToConnect: RPCServer) {
        self.connection = connection
        self.serverToConnect = serverToConnect
    }

    mutating func set(serverToConnect: RPCServer) {
        self.serverToConnect = serverToConnect
    }

    var navigationTitle: String {
        return R.string.localizable.walletConnectConnectionTitle()
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var confirmationButtonTitle: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var rejectionButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return R.color.white()!
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
                return "Name"
            case .network:
                return "Network"
            case .url:
                return "Connected To"
            }
        }
    }

    var allowChangeConnectionServer: Bool {
        return connection.server == nil
    }

    func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
        let headerName = sections[section].title
        switch sections[section] {
        case .name:
            return .init(title: .normal(connection.name), headerName: headerName, configuration: .init(section: section))
        case .network:
            return .init(title: .normal(serverToConnect.displayName), headerName: headerName, configuration: .init(section: section))
        case .url:
            return .init(title: .normal(connection.url.absoluteString), headerName: headerName, configuration: .init(section: section))
        }
    }
}
