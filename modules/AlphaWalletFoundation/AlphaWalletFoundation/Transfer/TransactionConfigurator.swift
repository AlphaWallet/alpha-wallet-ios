// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletLogger

public enum TransactionConfiguratorError: LocalizedError {
    case impossibleToBuildConfiguration

    public var errorDescription: String? {
        return "Impossible To Build Configuration"
    }
}

public class TransactionConfigurator {
    public let session: WalletSession

    public var currentConfiguration: TransactionConfiguration {
        switch selectedConfigurationType {
        case .standard:
            return configurations.standard
        case .slow, .fast, .rapid:
            return configurations[selectedConfigurationType]!
        case .custom:
            return configurations.custom
        }
    }

    public var gasValue: BigUInt {
        return currentConfiguration.gasPrice * currentConfiguration.gasLimit
    }

    public var toAddress: AlphaWallet.Address? {
        switch transaction.transactionType {
        case .nativeCryptocurrency:
            return transaction.recipient
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
            return transaction.contract
        }
    }

    public var value: BigUInt {
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
        gasPriceWarning(forConfiguration: currentConfiguration)
    }

    public private(set) var transaction: UnconfirmedTransaction
    public var selectedConfigurationType: TransactionConfigurationType = .standard
    public var configurations: TransactionConfigurations

    private var isGasLimitSpecifiedByTransaction: Bool {
        transaction.gasLimit != nil
    }
    private let analytics: AnalyticsLogger
    private let networkService: NetworkService
    private let gasPriceEstimator: LegacyGasPriceEstimator
    private var cancellable = Set<AnyCancellable>()
    private let gasPriceSubject = PassthroughSubject<BigUInt, Never>()
    private let nonceSubject = PassthroughSubject<Int, Never>()
    private let gasLimitSubject = PassthroughSubject<BigUInt, Never>()

    public var gasPrice: AnyPublisher<BigUInt, Never> {
        gasPriceSubject.eraseToAnyPublisher()
    }

    public var nonce: AnyPublisher<Int, Never> {
        nonceSubject.eraseToAnyPublisher()
    }

    public var gasLimit: AnyPublisher<BigUInt, Never> {
        gasLimitSubject.eraseToAnyPublisher()
    }

    public var objectChanges: AnyPublisher<Void, Never> {
        Publishers.Merge3(gasPrice.mapToVoid(), gasLimit.mapToVoid(), nonce.mapToVoid())
            .eraseToAnyPublisher()
    }
    private let tokensService: TokenViewModelState
    private let configuration: TransactionType.Configuration

    public init(session: WalletSession,
                analytics: AnalyticsLogger,
                transaction: UnconfirmedTransaction,
                networkService: NetworkService,
                tokensService: TokenViewModelState,
                configuration: TransactionType.Configuration) {

        self.configuration = configuration
        self.tokensService = tokensService
        self.session = session
        self.analytics = analytics
        self.transaction = transaction
        self.networkService = networkService
        self.gasPriceEstimator = LegacyGasPriceEstimator(
            blockchainProvider: session.blockchainProvider,
            networkService: networkService)

        let standardConfiguration = TransactionConfigurator.createConfiguration(server: session.server, gasPriceEstimator: gasPriceEstimator, transaction: transaction)
        self.configurations = .init(standard: standardConfiguration)
    }

    private func updateTransaction(value: BigUInt) {
        let tx = self.transaction
        self.transaction = .init(transactionType: tx.transactionType, value: value, recipient: tx.recipient, contract: tx.contract, data: tx.data, gasLimit: tx.gasLimit, gasPrice: tx.gasPrice, nonce: tx.nonce)
    }

    private func estimateGasLimit() {
        session.blockchainProvider
            .gasLimit(wallet: session.account.address, value: value, toAddress: toAddress, data: currentConfiguration.data)
            .sink(receiveCompletion: { result in
                guard case .failure(let e) = result else { return }
                infoLog("[Transaction Confirmation] Error estimating gas limit: \(e)")
                logError(e, rpcServer: self.session.server)
            }, receiveValue: { gasLimit in
                infoLog("[Transaction Confirmation] Using gas limit: \(gasLimit)")
                var customConfig = self.configurations.custom
                customConfig.setEstimated(gasLimit: gasLimit)
                self.configurations.custom = customConfig
                var defaultConfig = self.configurations.standard
                defaultConfig.setEstimated(gasLimit: gasLimit)
                self.configurations.standard = defaultConfig

                //Careful to not create if they don't exist
                for each: TransactionConfigurationType in [.slow, .fast, .rapid] {
                    guard var config = self.configurations[each] else { continue }
                    config.setEstimated(gasLimit: gasLimit)
                    self.configurations[each] = config
                }

                self.gasLimitSubject.send(gasLimit)
            }).store(in: &cancellable)
    }

    private func estimateGasPrice() {
        gasPriceEstimator.estimateGasPrice()
            .sink(receiveCompletion: { [session] result in
                guard case .failure(let e) = result else { return }
                logError(e, rpcServer: session.server)
            }, receiveValue: { estimates in
                let standard = estimates.standard
                var customConfig = self.configurations.custom
                customConfig.setEstimated(gasPrice: standard)
                var defaultConfig = self.configurations.standard
                defaultConfig.setEstimated(gasPrice: standard)

                if self.shouldUseEstimatedGasPrice(standard) {
                    self.configurations.custom = customConfig
                    self.configurations.standard = defaultConfig
                }

                for each: TransactionConfigurationType in [.slow, .fast, .rapid] {
                    guard let estimate = estimates[each] else { continue }
                    //Since there's a price estimate, we want to add that config if it's missing
                    var config = self.configurations[each] ?? defaultConfig
                    config.setEstimated(gasPrice: estimate)
                    self.configurations[each] = config
                }

                self.gasPriceSubject.send(standard)
            }).store(in: &cancellable)
    }

    public func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigUInt) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice.max > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    public func gasLimitWarning(forConfiguration configuration: TransactionConfiguration) -> GasLimitWarning? {
        if configuration.gasLimit > ConfigureTransaction.gasLimitMax {
            return .tooHighCustomGasLimit
        }
        return nil
    }

    public func gasFeeWarning(forConfiguration configuration: TransactionConfiguration) -> GasFeeWarning? {
        if (configuration.gasPrice * configuration.gasLimit) > ConfigureTransaction.gasFeeMax {
            return .tooHighGasFee
        }
        return nil
    }

    public func gasPriceWarning(forConfiguration configuration: TransactionConfiguration) -> GasPriceWarning? {
        if let fastestConfig = configurations.fastestThirdPartyConfiguration, configuration.gasPrice > fastestConfig.gasPrice {
            return .tooHighCustomGasPrice
        }
        //Conversion to gwei is needed so we that 17 (entered) is equal to 17.1 (fetched). Because 17.1 is displayed as "17" in the UI and might confuse the user if it's not treated as equal
        if let slowestConfig = configurations.slowestThirdPartyConfiguration, (configuration.gasPrice / BigUInt(EthereumUnit.gwei.rawValue)) < (slowestConfig.gasPrice / BigUInt(EthereumUnit.gwei.rawValue)) {
            return .tooLowCustomGasPrice
        }
        switch session.server.serverWithEnhancedSupport {
        case .main:
            if (configurations.standard.gasPrice / BigUInt(EthereumUnit.gwei.rawValue)) > Constants.highStandardEthereumMainnetGasThresholdGwei {
                return .networkCongested
            }
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            break
        }
        return nil
    }

    private static func createConfiguration(server: RPCServer, gasPriceEstimator: LegacyGasPriceEstimator, transaction: UnconfirmedTransaction) -> TransactionConfiguration {
        let maxGasLimit = GasLimitConfiguration.maxGasLimit(forServer: server)
        let gasPrice = server.defaultLegacyGasPrice(usingGasPrice: transaction.gasPrice?.max)
        let gasLimit: BigUInt

        switch transaction.transactionType {
        case .nativeCryptocurrency:
            gasLimit = GasLimitConfiguration.minGasLimit
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
            gasLimit = transaction.gasLimit ?? maxGasLimit
        }

        return TransactionConfiguration(gasPrice: gasPrice, gasLimit: gasLimit, data: transaction.data)
    }

    public func start() {
        estimateGasPrice()
        if !isGasLimitSpecifiedByTransaction {
            estimateGasLimit()
        }
        computeNonce()
        adjustTransactionValue()
    }

    private func useNonce(_ nonce: Int) {
        var customConfig = configurations.custom
        if let existingNonce = customConfig.nonce, existingNonce > 0 {
            //no-op
        } else {
            customConfig.set(nonce: nonce)
            configurations.custom = customConfig
            var defaultConfig = self.configurations.standard
            defaultConfig.set(nonce: nonce)
            configurations.standard = defaultConfig

            for each: TransactionConfigurationType in [.slow, .fast, .rapid] {
                //We don't want to add that config if it's missing (e.g. testnets don't have them)
                if var config = configurations[each] {
                    config.set(nonce: nonce)
                    configurations[each] = config
                }
            }

            nonceSubject.send(nonce)
        }
    }

    private func computeNonce() {
        if let nonce = transaction.nonce, nonce > 0 {
            useNonce(Int(nonce))
        } else {
            session.blockchainProvider
                .nextNonce(wallet: session.account.address)
                .sink(receiveCompletion: { [session] result in
                    guard case .failure(let e) = result else { return }
                    logError(e, rpcServer: session.server)
                }, receiveValue: {
                    self.useNonce($0)
                }).store(in: &cancellable)
        }
    }

    private func adjustTransactionValue() {
        let transactionType = transaction.transactionType
        Just(transactionType.tokenObject)
            .filter { [configuration] _ in
                guard case .sendFungiblesTransaction = configuration else { return false }
                return true
            }.flatMap { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
                switch token.type {
                case .nativeCryptocurrency:
                    let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                    return tokensService.tokenViewModelPublisher(for: etherToken)
                case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return tokensService.tokenViewModelPublisher(for: token)
                }
            }.compactMap { $0 }
            .sink { token in
                switch token.type {
                case .nativeCryptocurrency:
                    switch transactionType.amount {
                    case .notSet, .none, .amount:
                        break
                    case .allFunds:
                        //NOTE: ignore passed value of 'allFunds', as we recalculating it again
                        if token.balance.value > self.gasValue {
                            self.updateTransaction(value: token.balance.value - self.gasValue)
                        } else {
                            self.updateTransaction(value: .zero)
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
            nonce: currentConfiguration.nonce ?? -1,
            data: currentConfiguration.data,
            gasPrice: .legacy(gasPrice: currentConfiguration.gasPrice),
            gasLimit: currentConfiguration.gasLimit,
            server: session.server,
            transactionType: transaction.transactionType)
    }

    public func chooseCustomConfiguration(_ configuration: TransactionConfiguration) {
        configurations.custom = configuration
        selectedConfigurationType = .custom
        gasPriceSubject.send(configuration.gasPrice)
    }

    public func chooseDefaultConfigurationType(_ configurationType: TransactionConfigurationType) {
        selectedConfigurationType = configurationType
        gasPriceSubject.send(currentConfiguration.gasPrice)
    }
}
