//
//  TokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.07.2022.
//

import Foundation
import AlphaWalletTokenScript
import BigInt

public protocol TokenIdentifiable {
    var contractAddress: AlphaWallet.Address { get }
    var server: RPCServer { get }
    var type: TokenType { get }
}

public struct TokenViewModel {
    public let contractAddress: AlphaWallet.Address
    public let symbol: String
    public let decimals: Int
    public let server: RPCServer
    public let type: TokenType
    public let name: String
    public let shouldDisplay: Bool
    public let balance: BalanceViewModel
    public let tokenScriptOverrides: TokenScriptOverrides?
}

public struct TokenScriptOverrides {
    public let title: String
    public let titleInPluralForm: String
    public let shortTitleInPluralForm: String
    public let symbolInPluralForm: String
    public let hasNoBaseAssetDefinition: Bool
    public let server: RPCServerOrAny?

    init(token: TokenScriptSupportable, tokenAdaptor: TokenAdaptor) {
        let xmlHandler = tokenAdaptor.xmlHandler(token: token)
        self.symbolInPluralForm = tokenAdaptor.symbolInPluralForm2(token: token)
        self.title = tokenAdaptor.title(token: token)
        //NOTE: replace if needed
        switch token.type {
        case .erc20, .nativeCryptocurrency:
            self.shortTitleInPluralForm = tokenAdaptor.shortTitleInPluralForm(token: token)
            self.titleInPluralForm = tokenAdaptor.titleInPluralForm(token: token)
        case .erc875, .erc1155, .erc721, .erc721ForTickets:
            self.shortTitleInPluralForm = tokenAdaptor.shortTitleInPluralForm(token: token)
            self.titleInPluralForm = tokenAdaptor.titleInPluralFormOptional(token: token) ?? tokenAdaptor.titleInPluralForm(token: token)
        }

        self.hasNoBaseAssetDefinition = xmlHandler.hasNoBaseAssetDefinition
        self.server = xmlHandler.server
    }
}

extension TokenViewModel: BalanceRepresentable { }

extension TokenScriptOverrides: Hashable { }

extension TokenViewModel: TokenFilterable {
    public var balanceNft: [TokenBalanceValue] { balance.balance }
    public var valueBI: BigUInt { balance.value }
}

extension TokenViewModel: TokenSortable {
    public var value: BigUInt { balance.value }
}

extension TokenViewModel: TokenScriptOverridesSupportable { }
extension TokenViewModel: TokenBalanceSupportable { }

extension TokenViewModel: Equatable {
    public static func == (lhs: TokenViewModel, rhs: TokenViewModel) -> Bool {
        return lhs.contractAddress == rhs.contractAddress && lhs.server == rhs.server
    }

    public static func == (lhs: TokenViewModel, rhs: Token) -> Bool {
        return lhs.contractAddress == rhs.contractAddress && lhs.server == rhs.server
    }
}

extension TokenViewModel: Hashable {

    public var nonZeroBalance: [TokenBalanceValue] {
        return Array(balance.balance.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
    }

    public init(token: Token) {
        self.contractAddress = token.contractAddress
        self.server = token.server
        self.name = token.name
        self.symbol = token.symbol
        self.decimals = token.decimals
        self.type = token.type
        self.shouldDisplay = token.shouldDisplay

        switch token.type {
        case .nativeCryptocurrency:
            self.balance = .init(balance: NativecryptoBalanceViewModel(balance: token, ticker: nil))
        case .erc20:
            self.balance = .init(balance: Erc20BalanceViewModel(balance: token, ticker: nil))
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            self.balance = .init(balance: NFTBalanceViewModel(balance: token, ticker: nil))
        }
        self.tokenScriptOverrides = nil
    }

    public func override(balance: BalanceViewModel) -> TokenViewModel {
        return .init(contractAddress: contractAddress, symbol: symbol, decimals: decimals, server: server, type: type, name: name, shouldDisplay: shouldDisplay, balance: balance, tokenScriptOverrides: tokenScriptOverrides)
    }

    public func override(tokenScriptOverrides: TokenScriptOverrides) -> TokenViewModel {
        return .init(contractAddress: contractAddress, symbol: symbol, decimals: decimals, server: server, type: type, name: name, shouldDisplay: shouldDisplay, balance: balance, tokenScriptOverrides: tokenScriptOverrides)
    }

    public func override(shouldDisplay: Bool) -> TokenViewModel {
        return .init(contractAddress: contractAddress, symbol: symbol, decimals: decimals, server: server, type: type, name: name, shouldDisplay: shouldDisplay, balance: balance, tokenScriptOverrides: tokenScriptOverrides)
    }
}
