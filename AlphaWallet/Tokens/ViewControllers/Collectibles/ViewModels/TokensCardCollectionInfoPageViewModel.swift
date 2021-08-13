//
//  TokensCardCollectionInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

enum TokensCardCollectionInfoPageViewConfiguration {
    case field(viewModel: TokenInstanceAttributeViewModel)
    case header(viewModel: TokenInfoHeaderViewModel)
}

struct TokensCardCollectionInfoPageViewModel {

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    private let tokenObject: TokenObject

    let server: RPCServer
    var contractAddress: AlphaWallet.Address {
        tokenObject.contractAddress
    }
    let tokenHolders: [TokenHolder]
    var configurations: [TokensCardCollectionInfoPageViewConfiguration] = []

    init(server: RPCServer, token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol, forWallet wallet: Wallet) {
        self.server = server
        self.tokenObject = token
        tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: wallet)
        configurations = generateConfigurations(token, tokenHolders: tokenHolders)
    }

    var issuerViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Issuer", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("Enjin"))
    }

    var totalReserveViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Total Reserve", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("3 ETH"))
    }

    var createdDateViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Created", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("27 Apr 2021 10:52:15"))
    }

    var assetsViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Assets", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("215 Assets in 4 Types"))
    }

    var meltsViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Melts", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("0"))
    }

    var hodlersViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Hodlers", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("1"))
    }

    var transfersViewModel: TokenInstanceAttributeViewModel {
        return .init(title: "Transfers", attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString("0"))
    }

    var descriptionViewModel: TokenInstanceAttributeViewModel {
        let value = "This is Mathilde Cretier's artwork collection. It was reproduced by tomek.eth"
        return .init(title: nil, attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(value, alignment: .left), isSeparatorHidden: true)
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var iconImage: Subscribable<TokenImage> {
        tokenObject.icon
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: server)
    }

    func generateConfigurations(_ tokenObject: TokenObject, tokenHolders: [TokenHolder]) -> [TokensCardCollectionInfoPageViewConfiguration] {
        var configurations: [TokensCardCollectionInfoPageViewConfiguration] = []

        configurations = [
            .header(viewModel: .init(title: "Details")),
            .field(viewModel: issuerViewModel),
            .field(viewModel: createdDateViewModel),
            .field(viewModel: assetsViewModel),
            .field(viewModel: meltsViewModel),
            .field(viewModel: hodlersViewModel),
            .field(viewModel: transfersViewModel),
        ]

        configurations += [
            .header(viewModel: .init(title: "Description")),
            .field(viewModel: descriptionViewModel),
        ]

        return configurations
    }
}

