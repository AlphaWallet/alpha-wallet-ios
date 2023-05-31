// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletCore
import AlphaWalletFoundation
import Combine
import Foundation

extension WalletSession {
    static func make(account: Wallet = .make(), server: RPCServer = .main, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService()) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        let importToken: ImportToken = .make(server: server)
        let nftProvider = FakeNftProvider()
        let tokenAdaptor = TokenAdaptor(assetDefinitionStore: .make(), eventsDataStore: FakeEventsDataStore(account: account), wallet: account, nftProvider: nftProvider)
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider(), tokenAdaptor: tokenAdaptor, apiNetworking: FakeApiNetworking())
    }

    static func make(account: Wallet = .make(), server: RPCServer = .main, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService(), importToken: TokenImportable & TokenOrContractFetchable) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        let nftProvider = FakeNftProvider()
        let tokenAdaptor = TokenAdaptor(assetDefinitionStore: .make(), eventsDataStore: FakeEventsDataStore(account: account), wallet: account, nftProvider: nftProvider)
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider(), tokenAdaptor: tokenAdaptor, apiNetworking: FakeApiNetworking())
    }

    static func makeStormBirdSession(account: Wallet = .makeStormBird(), server: RPCServer, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService()) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        let importToken: ImportToken = .make(server: server)
        let nftProvider = FakeNftProvider()
        let tokenAdaptor = TokenAdaptor(assetDefinitionStore: .make(), eventsDataStore: FakeEventsDataStore(account: account), wallet: account, nftProvider: nftProvider)
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider(), tokenAdaptor: tokenAdaptor, apiNetworking: FakeApiNetworking())
    }
}

class FakeApiNetworking: ApiNetworking {
    func gasPriceEstimates() -> AnyPublisher<AlphaWalletFoundation.LegacyGasEstimates, AlphaWalletCore.PromiseError> {
        return .fail(PromiseError(error: ApiNetworkingError.methodNotSupported))
    }

    func normalTransactions(walletAddress: AlphaWallet.Address,
                            sortOrder: GetTransactions.SortOrder,
                            pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }
}
