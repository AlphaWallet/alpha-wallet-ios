//
//  Token.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.05.2022.
//

import Foundation
import AlphaWalletOpenSea
import AlphaWalletTokenScript
import BigInt

public struct Token: Equatable, Hashable {
    public let primaryKey: String
    public let contractAddress: AlphaWallet.Address
    public let symbol: String
    public let decimals: Int
    public let server: RPCServer
    public let type: TokenType
    public let name: String
    public let value: BigUInt
    public let balance: [TokenBalanceValue]
    public let shouldDisplay: Bool
    public let info: TokenInfo

    public var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }

    public var isERC721Or1155AndNotForTickets: Bool {
        switch type {
        case .erc721, .erc1155:
            return true
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return false
        }
    }

    public var nonZeroBalance: [TokenBalanceValue] {
        return Array(balance.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
    }

    public var nftBalanceValue: [NonFungibleFromJson] {
        balance.compactMap { $0.nonFungibleBalance }
    }

    public init(contract: AlphaWallet.Address = Constants.nullAddress,
                server: RPCServer = .main,
                name: String = "",
                symbol: String = "",
                decimals: Int = 0,
                value: BigUInt = .zero,
                isCustom: Bool = false,
                isDisabled: Bool = false,
                shouldDisplay: Bool = false,
                type: TokenType = .erc20,
                balance: [TokenBalanceValue] = [],
                sortIndex: Int? = nil) {

        self.primaryKey = TokenObject.generatePrimaryKey(fromContract: contract, server: server)
        self.contractAddress = contract
        self.server = server
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.value = value
        self.type = type
        self.balance = balance
        self.shouldDisplay = shouldDisplay
        self.info = .init(uid: self.primaryKey)
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.primaryKey == rhs.primaryKey
    }
}

extension Token {
    init(tokenObject: TokenObject) {
        name = tokenObject.name
        primaryKey = tokenObject.primaryKey
        server = tokenObject.server
        contractAddress = tokenObject.contractAddress
        symbol = tokenObject.symbol
        decimals = tokenObject.decimals
        type = tokenObject.type
        shouldDisplay = tokenObject.shouldDisplay
        value = tokenObject.valueBigInt
        balance = Array(tokenObject.balance.map { TokenBalanceValue(balance: $0) })
        info = .init(tokenInfoObject: tokenObject.info)
    }
}

extension Token: TokenScriptSupportable {
    public var valueBI: BigUInt { value }
    public var balanceNft: [TokenBalanceValue] { balance }
}
extension Token: TokenFilterable { }
extension Token: TokenSortable { }
extension Token: TokenActionsIdentifiable { }
extension Token: BalanceRepresentable { }
extension Token: TokenIdentifiable { }
