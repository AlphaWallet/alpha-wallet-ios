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
    //TODO reduce usage and remove
    func getContractName(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError>
    func getContractSymbol(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError>
    func getDecimals(for address: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError>
    func getTokenType(for address: AlphaWallet.Address) -> AnyPublisher<TokenType, SessionTaskError>
    func getContractNameAsync(for address: AlphaWallet.Address) async throws -> String
    func getContractSymbolAsync(for address: AlphaWallet.Address) async throws -> String
    func getDecimalsAsync(for address: AlphaWallet.Address) async throws -> Int
    func getTokenTypeAsync(for address: AlphaWallet.Address) async throws -> TokenType
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
        asFutureThrowable { try await self.getContractName.getName(for: address) }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
    }

    public func getContractSymbol(for address: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError> {
        asFutureThrowable { try await self.getContractSymbol.getSymbol(for: address) }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
    }

    public func getDecimals(for address: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        asFutureThrowable { try await self.getContractDecimals.getDecimals(for: address) }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
    }

    public func getTokenType(for address: AlphaWallet.Address) -> AnyPublisher<TokenType, SessionTaskError> {
        asFutureThrowable { try await self.getTokenType.getTokenType(for: address) }.mapError { SessionTaskError(error: $0) }.eraseToAnyPublisher()
    }

    public func getContractNameAsync(for address: AlphaWallet.Address) async throws -> String {
        try await self.getContractName.getName(for: address)
    }

    public func getContractSymbolAsync(for address: AlphaWallet.Address) async throws -> String {
        try await getContractSymbol.getSymbol(for: address)
    }

    public func getDecimalsAsync(for address: AlphaWallet.Address) async throws -> Int {
        try await getContractDecimals.getDecimals(for: address)
    }

    public func getTokenTypeAsync(for address: AlphaWallet.Address) async throws -> TokenType {
        try await getTokenType.getTokenType(for: address)
    }

    public func getErc20Balance(for address: AlphaWallet.Address) -> AnyPublisher<BigUInt, SessionTaskError> {
        return asFutureThrowable {
            try await self.getErc20Balance.getErc20Balance(for: self.account.address, contract: address)
        }.mapError { SessionTaskError(error: $0) }
        .eraseToAnyPublisher()
    }

    public func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        return asFutureThrowable {
            try await self.getErc875Balance.getErc875TokenBalance(for: address, contract: contract)
        }.mapError { SessionTaskError(error: $0) }
        .eraseToAnyPublisher()
    }

    public func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        return asFutureThrowable {
            try await self.getErc721ForTicketsBalance.getErc721ForTicketsTokenBalance(for: self.account.address, contract: address)
        }.mapError { SessionTaskError(error: $0) }
        .eraseToAnyPublisher()
    }

    public func getErc721Balance(for address: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        return asFutureThrowable {
            try await self.getErc721Balance.getErc721TokenBalance(for: self.account.address, contract: address)
        }.mapError { SessionTaskError(error: $0) }
        .eraseToAnyPublisher()
    }

    static func shouldRetry(error: Error) -> Bool {
        return true
    }
}
