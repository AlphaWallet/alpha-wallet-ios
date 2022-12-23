//
//  TokenProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.08.2021.
//

import AlphaWalletCore
import PromiseKit
import BigInt

// NOTE: Think about the name, more fittable name is needed
public protocol TokenProviderType: AnyObject {
    func getContractName(for address: AlphaWallet.Address) -> Promise<String>
    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String>
    func getDecimals(for address: AlphaWallet.Address) -> Promise<Int>
    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType>
    func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance>
    func getErc20Balance(for address: AlphaWallet.Address) -> Promise<BigInt>
    func getErc875Balance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getErc721Balance(for address: AlphaWallet.Address) -> Promise<[String]>
}

public class TokenProvider: TokenProviderType {
    private let account: Wallet
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    private lazy var getEthBalance = GetEthBalance(forServer: server, analytics: analytics)
    private lazy var getContractDecimals = GetContractDecimals(forServer: server)
    private lazy var getContractSymbol = GetContractSymbol(forServer: server)
    private lazy var getContractName = GetContractName(forServer: server)
    private lazy var getErc20Balance = GetErc20Balance(forServer: server)
    private lazy var getErc875Balance = GetErc875Balance(forServer: server)
    private lazy var getErc721ForTicketsBalance = GetErc721ForTicketsBalance(forServer: server)
    private lazy var getErc721Balance = GetErc721Balance(forServer: server)
    private lazy var getTokenType = GetTokenType(forServer: server)

    public init(account: Wallet, server: RPCServer, analytics: AnalyticsLogger) {
        self.account = account
        self.server = server
        self.analytics = analytics
    }

    public func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        //NOTE: retrying is performing via APIKit.session request
        return getEthBalance.getBalance(for: address)
    }

    public func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        getContractName.getName(for: address)
    }

    public func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String> {
        getContractSymbol.getSymbol(for: address)
    }

    public func getDecimals(for address: AlphaWallet.Address) -> Promise<Int> {
        getContractDecimals.getDecimals(for: address)
    }

    public func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType> {
        getTokenType.getTokenType(for: address)
    }

    public func getErc20Balance(for address: AlphaWallet.Address) -> Promise<BigInt> {
        getErc20Balance.getErc20Balance(for: account.address, contract: address)
    }

    public func getErc875Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        getErc875Balance.getErc875TokenBalance(for: account.address, contract: address)
    }

    public func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]> {
        getErc721ForTicketsBalance.getERC721ForTicketsTokenBalance(for: account.address, contract: address)
    }

    public func getErc721Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        getErc721Balance.getERC721TokenBalance(for: account.address, contract: address)
    }

    static func shouldRetry(error: Error) -> Bool {
        return true
    }
}
