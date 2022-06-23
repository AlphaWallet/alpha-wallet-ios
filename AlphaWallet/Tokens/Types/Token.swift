//
//  Token.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.05.2022.
//

import Foundation
import AlphaWalletOpenSea
import RealmSwift
import BigInt

struct Token: Equatable, Hashable {
    let primaryKey: String
    let contractAddress: AlphaWallet.Address
    let symbol: String
    let decimals: Int
    let server: RPCServer
    let type: TokenType
    let name: String
    let value: BigInt
    let balance: [TokenBalanceValue]
    let shouldDisplay: Bool
    let sortIndex: Int?
    let info: TokenInfo

    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }

    var isERC721Or1155AndNotForTickets: Bool {
        switch type {
        case .erc721, .erc1155:
            return true
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return false
        }
    }

    var valueDecimal: NSDecimalNumber? {
        let value = EtherNumberFormatter.plain.string(from: value, decimals: decimals)
        return value.optionalDecimalValue
    }

    var nonZeroBalance: [TokenBalanceValue] {
        return Array(balance.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
    }

    var nftBalanceValue: [NonFungibleFromJson] {
        balance.compactMap { $0.nonFungibleBalance }
    }

    init(
            contract: AlphaWallet.Address = Constants.nullAddress,
            server: RPCServer = .main,
            name: String = "",
            symbol: String = "",
            decimals: Int = 0,
            value: BigInt = .zero,
            isCustom: Bool = false,
            isDisabled: Bool = false,
            shouldDisplay: Bool = false,
            type: TokenType = .erc20,
            balance: [TokenBalanceValue] = [],
            sortIndex: Int? = nil
    ) {
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
        self.sortIndex = sortIndex
        self.info = .init(uid: self.primaryKey)
    }

    init(tokenObject: TokenObject) {
        name = tokenObject.name
        primaryKey = tokenObject.primaryKey
        server = tokenObject.server
        contractAddress = tokenObject.contractAddress
        symbol = tokenObject.symbol
        decimals = tokenObject.decimals
        type = tokenObject.type
        shouldDisplay = tokenObject.shouldDisplay
        sortIndex = tokenObject.sortIndex.value
        value = tokenObject.valueBigInt
        balance = Array(tokenObject.balance.map { TokenBalanceValue(balance: $0) })
        info = .init(tokenInfoObject: tokenObject.info)
    }

    static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.contractAddress == rhs.contractAddress &&
            lhs.symbol == rhs.symbol &&
            lhs.decimals == rhs.decimals &&
            lhs.server == rhs.server &&
            lhs.type == rhs.type &&
            lhs.name == rhs.name &&
            lhs.value == rhs.value &&
            lhs.balance == rhs.balance &&
            lhs.shouldDisplay == rhs.shouldDisplay &&
            lhs.sortIndex == rhs.sortIndex &&
            lhs.info == rhs.info
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(primaryKey)
        hasher.combine(server)
        hasher.combine(contractAddress)
        hasher.combine(symbol)
        hasher.combine(decimals)
        hasher.combine(type.rawValue)
    }
}
