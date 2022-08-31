//
//  RequesterViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.06.2022.
//

import Foundation

protocol RequesterViewModel {
    var requester: Requester { get }

    var viewModels: [SignatureConfirmationViewModel.ViewType] { get }
}

extension RequesterViewModel {
    var iconUrl: URL? { return requester.iconUrl }
}

struct DeepLinkRequesterViewModel: RequesterViewModel {
    let requester: Requester

    var viewModels: [SignatureConfirmationViewModel.ViewType] {
        var viewModels: [SignatureConfirmationViewModel.ViewType] = []

        var dappNameHeader: String { R.string.localizable.walletConnectDappName() }
        viewModels += [
            .header(.init(title: .normal(requester.shortName), headerName: dappNameHeader, configuration: .init(section: 0)))
        ]

        if let dappUrl = requester.url {
            var dappWebsiteHeader: String { R.string.localizable.requesterFieldUrl() }
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

struct DappRequesterViewModel: RequesterViewModel {
    let requester: Requester

    var viewModels: [SignatureConfirmationViewModel.ViewType] {
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
