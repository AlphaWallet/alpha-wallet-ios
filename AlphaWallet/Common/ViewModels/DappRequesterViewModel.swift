//
//  DappRequesterViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2022.
//

import Foundation
import AlphaWalletFoundation

struct DappRequesterViewModel: RequesterViewModel {
    let requester: Requester

    var viewModels: [Any] {
        var viewModels: [SignatureConfirmationViewModel.ViewType] = []

        var dappNameHeader: String { R.string.localizable.walletConnectDappName() }
        viewModels += [
            .header(.init(title: .normal(requester.shortName), headerName: dappNameHeader, configuration: .init(section: 0)))
        ]

        if let dappUrl = requester.url {
            var dappWebsiteHeader: String { R.string.localizable.walletConnectDappWebsite() }
            viewModels += [
                .header(.init(title: .normal(dappUrl.absoluteString), headerName: dappWebsiteHeader, configuration: .init(section: 0))),
            ]
        }

        if let server = requester.server {
            var dappServerHeader: String { R.string.localizable.settingsNetworkButtonTitle() }
            viewModels += [
                .header(.init(title: .normal(server.name), headerName: dappServerHeader, configuration: .init(section: 0)))
            ]
        }

        return viewModels
    }
}
