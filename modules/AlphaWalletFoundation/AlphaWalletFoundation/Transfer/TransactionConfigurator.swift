// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletLogger

public class TransactionConfigurator {
    private let tokensService: TokensProcessingPipeline
    private let configuration: TransactionType.Configuration
    private let networkService: NetworkService
    private var cancellable = Set<AnyCancellable>()

    public let session: WalletSession

    public var gasFee: BigUInt {
        return gasPriceEstimator.gasPrice.value.max * gasLimit.value
    }

    public var toAddress: AlphaWallet.Address? {
        switch transaction.transactionType {
        case .nativeCryptocurrency:
            return transaction.recipient
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
            return transaction.contract
        }
    }

    private var value: BigUInt {
        //TODO why not all `transaction.value`? Shouldn't the other types of transactions make sure their `transaction.value` is 0?
        switch transaction.transactionType {
        case .nativeCryptocurrency: return transaction.value
        case .erc20Token: return 0
        case .erc875Token: return 0
        case .erc721Token: return 0
        case .erc721ForTicketToken: return 0
        case .erc1155Token: return 0
        case .prebuilt: return transaction.value
        }
    }

    public var gasPriceWarning: GasPriceWarning? {
        return gasPriceEstimator.gasPrice.warnings.compactMap { $0 as? GasPriceWarning }.first
    }

    public private(set) var transaction: UnconfirmedTransaction
    public var selectedGasSpeed: GasSpeed { return gasPriceEstimator.selectedGasSpeed }
    public let gasPriceEstimator: GasPriceEstimator

    @Published public private (set) var nonce: Int?
    @Published public private (set) var gasLimit: EstimatedValue<BigUInt>
    @Published public private (set) var data: Data = Data()

    public var objectChanges: AnyPublisher<Void, Never> {
        Publishers.Merge3(gasPriceEstimator.gasPricePublisher.mapToVoid(), $gasLimit.mapToVoid(), $nonce.mapToVoid())
            .eraseToAnyPublisher()
    }

    public init(session: WalletSession,
                transaction: UnconfirmedTransaction,
                networkService: NetworkService,
                tokensService: TokensProcessingPipeline,
                configuration: TransactionType.Configuration) {

        self.configuration = configuration
        self.tokensService = tokensService
        self.session = session
        self.transaction = transaction
        self.networkService = networkService

        if let gasPrice = transaction.gasPrice {
            switch gasPrice {
            case .legacy(let gasPrice):
                gasPriceEstimator = LegacyGasPriceEstimator(
                    blockchainProvider: session.blockchainProvider,
                    networking: session.blockchainExplorer,
                    initialGasPrice: gasPrice)
            case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas):
                gasPriceEstimator = Eip1559GasPriceEstimator(
                    blockchainProvider: session.blockchainProvider,
                    initialMaxFeePerGas: maxFeePerGas,
                    initialMaxPriorityFeePerGas: maxPriorityFeePerGas)
            }
        } else {
            if session.blockchainProvider.server.supportsEip1559 && Features.current.isAvailable(.isEip1559Enabled) && !isRunningTests() {
                gasPriceEstimator = Eip1559GasPriceEstimator(
                    blockchainProvider: session.blockchainProvider,
                    initialMaxFeePerGas: nil,
                    initialMaxPriorityFeePerGas: nil)
            } else {
                gasPriceEstimator = LegacyGasPriceEstimator(
                    blockchainProvider: session.blockchainProvider,
                    networking: session.blockchainExplorer,
                    initialGasPrice: nil)
            }
        }

        self.data = transaction.data
        self.gasLimit = TransactionConfigurator.defaultEstimatedGasLimit(transaction: transaction, server: session.server)
    }

    private static func defaultEstimatedGasLimit(transaction: UnconfirmedTransaction, server: RPCServer) -> EstimatedValue<BigUInt> {
        if let gasLimit = transaction.gasLimit {
            return .defined(gasLimit)
        } else {
            switch transaction.transactionType {
            case .nativeCryptocurrency:
                let gasLimit = GasLimitConfiguration.minGasLimit
                return .estimated(gasLimit)
            case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
                let gasLimit = GasLimitConfiguration.maxGasLimit(forServer: server)
                return .estimated(gasLimit)
            }
        }
    }

    private func updateTransaction(value: BigUInt) {
        let tx = self.transaction
        self.transaction = .init(transactionType: tx.transactionType, value: value, recipient: tx.recipient, contract: tx.contract, data: tx.data, gasLimit: tx.gasLimit, gasPrice: tx.gasPrice, nonce: tx.nonce)
    }

    private func estimateGasLimit() {
        if let gasLimit = transaction.gasLimit {
            //no-op
        } else {
            session.blockchainProvider
                .gasLimit(wallet: session.account.address, value: value, toAddress: toAddress, data: data)
                .retry(3)
                .sink(receiveCompletion: { result in
                    guard case .failure(let e) = result else { return }
                    infoLog("[Transaction Confirmation] Error estimating gas limit: \(e)")
                    logError(e, rpcServer: self.session.server)
                }, receiveValue: { [weak self] gasLimit in
                    guard let strongSelf = self else { return }
                    guard case .estimated = strongSelf.gasLimit else { return }
                    infoLog("[Transaction Confirmation] Using gas limit: \(gasLimit)")

                    strongSelf.gasLimit = .estimated(gasLimit)
                }).store(in: &cancellable)
        }
    }

    public func start() {
        estimateGasLimit()
        computeNonce()
        adjustTransactionValue()
    }

    public func set(customGasLimit: BigUInt) {
        guard gasLimit.value != customGasLimit else { return }
        gasLimit = .defined(customGasLimit)
    }

    public func set(customData: Data) {
        guard data != customData else { return }
        data = customData
    }

    public func set(customNonce: Int?) {
        if let value = nonce, value == customNonce { return }
        nonce = customNonce
    }

    private func computeNonce() {
        if let nonce = transaction.nonce, nonce > 0 {
            set(customNonce: Int(nonce))
        } else {
            session.blockchainProvider
                .nextNonce(wallet: session.account.address)
                .retry(3)
                .sink(receiveCompletion: { [session] result in
                    guard case .failure(let e) = result else { return }
                    logError(e, rpcServer: session.server)
                }, receiveValue: { [weak self] in
                    guard let strongSelf = self else { return }

                    if let existingNonce = strongSelf.nonce, existingNonce > 0 {
                        //no-op
                    } else {
                        strongSelf.set(customNonce: $0)
                    }
                }).store(in: &cancellable)
        }
    }

    private func adjustTransactionValue() {
        guard case .sendFungiblesTransaction = configuration else { return }
        let transactionType = transaction.transactionType

        Just(transactionType.tokenObject)
            .flatMap { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
                switch token.type {
                case .nativeCryptocurrency:
                    let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                    return tokensService.tokenViewModelPublisher(for: etherToken)
                case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return tokensService.tokenViewModelPublisher(for: token)
                }
            }.compactMap { $0 }
            .sink { [weak self] token in
                guard let strongSelf = self else { return }

                switch token.type {
                case .nativeCryptocurrency:
                    switch transactionType.amount {
                    case .notSet, .none, .amount:
                        break
                    case .allFunds:
                        //NOTE: ignore passed value of 'allFunds', as we recalculating it again
                        if token.balance.value > strongSelf.gasFee {
                            strongSelf.updateTransaction(value: token.balance.value - strongSelf.gasFee)
                        } else {
                            strongSelf.updateTransaction(value: .zero)
                        }
                    }
                case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                    break
                }
            }.store(in: &cancellable)
    }

    public func formUnsignedTransaction() -> UnsignedTransaction {
        return UnsignedTransaction(
            value: value,
            account: session.account.address,
            to: toAddress,
            nonce: nonce ?? -1,
            data: data,
            gasPrice: gasPriceEstimator.gasPrice.value,
            gasLimit: gasLimit.value,
            server: session.server,
            transactionType: transaction.transactionType)
    }
}
