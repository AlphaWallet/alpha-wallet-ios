//
//  TokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.07.2022.
//

import Foundation
import BigInt

struct TokenViewModel {
    let contractAddress: AlphaWallet.Address
    let symbol: String
    let decimals: Int
    let server: RPCServer
    let type: TokenType
    let name: String
    let shouldDisplay: Bool
    let balance: BalanceViewModel
    let tokenScriptOverrides: TokenScriptOverrides?
}

struct TokenScriptOverrides {
    let title: String
    let titleInPluralForm: String
    let shortTitleInPluralForm: String
    let symbolInPluralForm: String
    let hasNoBaseAssetDefinition: Bool
    let server: RPCServerOrAny?

    let xmlHandler: XMLHandler
}

extension TokenViewModel: BalanceRepresentable { }

extension TokenScriptOverrides {
    init(token: TokenScriptSupportable, assetDefinitionStore: AssetDefinitionStore, wallet: Wallet, eventsDataStore: NonActivityEventsDataStore) {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        self.symbolInPluralForm = token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        self.title = token.title(withAssetDefinitionStore: assetDefinitionStore)
        //NOTE: replace if needed
        switch token.type {
        case .erc20, .nativeCryptocurrency:
            self.shortTitleInPluralForm = token.shortTitleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
            self.titleInPluralForm = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        case .erc875, .erc1155, .erc721, .erc721ForTickets:
            self.shortTitleInPluralForm = token.shortTitleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
            self.titleInPluralForm = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet) ?? token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        }

        self.xmlHandler = xmlHandler
        self.hasNoBaseAssetDefinition = xmlHandler.hasNoBaseAssetDefinition
        self.server = xmlHandler.server
    }
}

extension TokenScriptOverrides: Hashable {
    static func == (lhs: TokenScriptOverrides, rhs: TokenScriptOverrides) -> Bool {
        return lhs.title == rhs.title && lhs.titleInPluralForm == rhs.titleInPluralForm && lhs.shortTitleInPluralForm == rhs.shortTitleInPluralForm && lhs.symbolInPluralForm == rhs.symbolInPluralForm && lhs.hasNoBaseAssetDefinition == rhs.hasNoBaseAssetDefinition && lhs.server == rhs.server
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(titleInPluralForm)
        hasher.combine(shortTitleInPluralForm)
        hasher.combine(symbolInPluralForm)
        hasher.combine(hasNoBaseAssetDefinition)
        hasher.combine(server)
        //NOTE: we don't want to add xmlHandler to compute hash value, for now
    }
}

extension TokenViewModel: TokenFilterable {
    var balanceNft: [TokenBalanceValue] { balance.balance }
    var valueBI: BigInt { balance.value }
}

extension TokenViewModel: TokenSortable {
    var value: BigInt { balance.value }
}

extension TokenViewModel: Equatable {
    static func == (lhs: TokenViewModel, rhs: TokenViewModel) -> Bool {
        return lhs.contractAddress.sameContract(as: rhs.contractAddress) && lhs.server == rhs.server
    }

    static func == (lhs: TokenViewModel, rhs: Token) -> Bool {
        return lhs.contractAddress.sameContract(as: rhs.contractAddress) && lhs.server == rhs.server
    }
}

extension TokenViewModel: Hashable {

    var nonZeroBalance: [TokenBalanceValue] {
        return Array(balance.balance.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
    }

    init(token: Token) {
        self.contractAddress = token.contractAddress
        self.server = token.server
        self.name = token.name
        self.symbol = token.symbol
        self.decimals = token.decimals
        self.type = token.type
        self.shouldDisplay = token.shouldDisplay

        switch token.type {
        case .nativeCryptocurrency:
            self.balance = .init(balance: NativecryptoBalanceViewModel(token: token, ticker: nil))
        case .erc20:
            self.balance = .init(balance: Erc20BalanceViewModel(token: token, ticker: nil))
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            self.balance = .init(balance: NFTBalanceViewModel(token: token, ticker: nil))
        }
        self.tokenScriptOverrides = nil
    }

    func override(balance: BalanceViewModel) -> TokenViewModel {
        return .init(contractAddress: contractAddress, symbol: symbol, decimals: decimals, server: server, type: type, name: name, shouldDisplay: shouldDisplay, balance: balance, tokenScriptOverrides: tokenScriptOverrides)
    }

    func override(tokenScriptOverrides: TokenScriptOverrides) -> TokenViewModel {
        return .init(contractAddress: contractAddress, symbol: symbol, decimals: decimals, server: server, type: type, name: name, shouldDisplay: shouldDisplay, balance: balance, tokenScriptOverrides: tokenScriptOverrides)
    }
}
