//
//  TokenProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.08.2021.
//

import AlphaWalletCore
import BigInt
import Combine

// NOTE: Think about the name, more fittable name is needed
public protocol TokenProviderType: AnyObject {
    func getContractName(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError>
    func getContractSymbol(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError>
    func getDecimals(for address: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError>
    func getTokenType(for address: AlphaWallet.Address) -> AnyPublisher<TokenType, SessionTaskError>
    func getErc20Balance(for address: AlphaWallet.Address) -> AnyPublisher<BigUInt, SessionTaskError>
    func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError>
    func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError>
    func getErc721Balance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError>
}

public class TokenProvider: TokenProviderType {
    private let account: Wallet
    private let blockchainProvider: BlockchainProvider

    private lazy var getContractDecimals = GetContractDecimals(blockchainProvider: blockchainProvider)
    private lazy var getContractSymbol = GetContractSymbol(blockchainProvider: blockchainProvider)
    private lazy var getContractName = GetContractName(blockchainProvider: blockchainProvider)
    private lazy var getErc20Balance = GetErc20Balance(blockchainProvider: blockchainProvider)
    private lazy var getErc875Balance = GetErc875Balance(blockchainProvider: blockchainProvider)
    private lazy var getErc721ForTicketsBalance = GetErc721ForTicketsBalance(blockchainProvider: blockchainProvider)
    private lazy var getErc721Balance = GetErc721Balance(blockchainProvider: blockchainProvider)
    private lazy var getTokenType = GetTokenType(blockchainProvider: blockchainProvider)

    public init(account: Wallet, blockchainProvider: BlockchainProvider) {
        self.account = account
        self.blockchainProvider = blockchainProvider
    }

    public func getContractName(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError> {
        getContractName.getName(for: address)
    }

    public func getContractSymbol(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError> {
        getContractSymbol.getSymbol(for: address)
    }

    public func getDecimals(for address: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        getContractDecimals.getDecimals(for: address)
    }

    public func getTokenType(for address: AlphaWallet.Address) -> AnyPublisher<TokenType, SessionTaskError> {
        getTokenType.getTokenType(for: address)
    }

    public func getErc20Balance(for address: AlphaWallet.Address) -> AnyPublisher<BigUInt, SessionTaskError> {
        getErc20Balance.getErc20Balance(for: account.address, contract: address)
    }

    public func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        getErc875Balance.getErc875TokenBalance(for: address, contract: contract)
    }

    public func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        getErc721ForTicketsBalance.getErc721ForTicketsTokenBalance(for: account.address, contract: address)
    }

    public func getErc721Balance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        getErc721Balance.getErc721TokenBalance(for: account.address, contract: address)
    }

    static func shouldRetry(error: Error) -> Bool {
        return true
    }
}
