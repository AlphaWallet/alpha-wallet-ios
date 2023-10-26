//
//  GetTokenType.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.10.2022.
//

import AlphaWalletCore
import BigInt

final actor GetTokenType {
    private var inFlightTasks: [String: Task<TokenType, Error>] = [:]
    private lazy var isErc1155Contract = IsErc1155Contract(blockchainProvider: blockchainProvider)
    private lazy var isErc875Contract = IsErc875Contract(blockchainProvider: blockchainProvider)
    private lazy var erc721ForTickers = IsErc721ForTicketsContract(blockchainProvider: blockchainProvider)
    private lazy var erc721 = IsErc721Contract(blockchainProvider: blockchainProvider)

    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<TokenType, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    public nonisolated func getTokenType(for address: AlphaWallet.Address) async throws -> TokenType {
        let key = address.eip55String
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<TokenType, Error> {
                let tokenType = await _getTokenType(for: address)
                await setTask(nil, forKey: key)
                return tokenType
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }

    /// `getTokenType` doesn't return .nativeCryptoCurrency type, fallback to erc20. Maybe need to throw an error?
    private nonisolated func _getTokenType(for address: AlphaWallet.Address) async -> TokenType {
        let numberOfTimesToRetryFetchContractData = 2
        let isErc875: Bool? = try? await attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [isErc875Contract] in
            //Function hash is "0x4f452b9a". This might cause many "execution reverted" RPC errors
            //TODO rewrite flow so we reduce checks for this as it causes too many "execution reverted" RPC errors and looks scary when we look in Charles proxy. Maybe check for ERC20 (via EIP165) as well as ERC721 in parallel first, then fallback to this ERC875 check
            try await isErc875Contract.getIsERC875Contract(for: address)
        }
        if let isErc875, isErc875 {
            return .erc875
        }

        let isErc721: Bool? = try? await attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [erc721] in
            try await erc721.getIsERC721Contract(for: address)
        }
        if let isErc721, isErc721 {
            let isErc721ForTickets: Bool? = try? await attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [erc721ForTickers] in
                try await erc721ForTickers.getIsErc721ForTicketContract(for: address)
            }
            if let isErc721ForTickets, isErc721ForTickets {
                return .erc721ForTickets
            } else {
                return .erc721
            }
        }

        let isErc1155: Bool? = try? await attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [isErc1155Contract] in
            try await isErc1155Contract.getIsErc1155Contract(for: address)
        }
        if let isErc1155, isErc1155 {
            return .erc1155
        }

        return .erc20
    }
}
