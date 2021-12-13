//
//  TokensCardCollectionInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt

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

    var createdDateViewModel: TokenInstanceAttributeViewModel {
        let string: String? = tokenHolders.first?.values["collectionCreatedDate"]?.generalisedTimeValue?.formatAsShortDateString()
        let attributedString: NSAttributedString? = string.flatMap { TokenInstanceAttributeViewModel.defaultValueAttributedString($0) }
        return .init(title: R.string.localizable.semifungiblesCreatedDate(), attributedValue: attributedString)
    }

    var descriptionViewModel: TokenInstanceAttributeViewModel {
        let string: String? = tokenHolders.first?.values["collectionDescription"]?.stringValue
        let attributedString: NSAttributedString? = string.flatMap { TokenInstanceAttributeViewModel.defaultValueAttributedString($0, alignment: .left) }
        return .init(title: nil, attributedValue: attributedString, isSeparatorHidden: true)
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
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails())),
            .field(viewModel: createdDateViewModel)
        ]

        configurations += [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription())),
            .field(viewModel: descriptionViewModel),
        ]

        return configurations
    }
}

