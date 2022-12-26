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
    func getErc20Balance(for address: AlphaWallet.Address) -> Promise<BigInt>
    func getErc875Balance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getErc721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getErc721Balance(for address: AlphaWallet.Address) -> Promise<[String]>
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

    public init(blockchainProvider: BlockchainProvider) {
        self.account = blockchainProvider.wallet
        self.blockchainProvider = blockchainProvider
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
