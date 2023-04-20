// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import Combine

enum TransactionsSource {
    case etherscan(apiKey: String?, apiUrl: URL)
    case blockscout(apiKey: String?, apiUrl: URL)
    case covalent(apiKey: String?)
    case oklink(apiKey: String?)
    case unknown
}

public enum TransactionProviderState: Int {
    case pending
    case running
    case stopped
}

public enum TransactionFetchType: String, CaseIterable {
    case normal
    case erc20
    case erc721
    case erc1155
}

public protocol SingleChainTransactionProvider: AnyObject {
    var state: TransactionProviderState { get }
    var completeTransaction: AnyPublisher<Result<Transaction, PendingTransactionProvider.PendingTransactionProviderError>, Never> { get }
    
    func start()
    func resume()
    func pause()
    func isServer(_ server: RPCServer) -> Bool
    func fetchLatestTransactions(fetchTypes: [TransactionFetchType]) -> AnyPublisher<[Transaction], PromiseError>
}
