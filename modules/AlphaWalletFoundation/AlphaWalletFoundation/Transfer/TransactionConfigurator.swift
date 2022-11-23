// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import PromiseKit
import Combine
import AlphaWalletCore

public protocol TransactionConfiguratorDelegate: AnyObject {
    func configurationChanged(in configurator: TransactionConfigurator)
    func gasLimitEstimateUpdated(to estimate: BigUInt, in configurator: TransactionConfigurator)
    func gasPriceEstimateUpdated(to estimate: BigUInt, in configurator: TransactionConfigurator)
    func updateNonce(to nonce: Int, in configurator: TransactionConfigurator)
}

public enum TransactionConfiguratorError: Error {
    case impossibleToBuildConfiguration

    var localizedDescription: String {
        return "Impossible To Build Configuration"
    }
}

public class TransactionConfigurator {
    public let session: WalletSession
    public weak var delegate: TransactionConfiguratorDelegate?

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

    private var maxGasLimit: BigUInt {
        GasLimitConfiguration.maxGasLimit(forServer: session.server)
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

    public var transaction: UnconfirmedTransaction
    public var selectedConfigurationType: TransactionConfigurationType = .standard
    public var configurations: TransactionConfigurations

    private var isGasLimitSpecifiedByTransaction: Bool {
        transaction.gasLimit != nil
    }
    private let analytics: AnalyticsLogger
    private let networkService: NetworkService
    private lazy var gasPriceEstimator = GasPriceEstimator(analytics: analytics, networkService: networkService)
    private lazy var gasLimitEstimator = GetGasLimit(account: session.account, server: session.server, analytics: analytics)
    private var cancelable = Set<AnyCancellable>()
    
    public init(session: WalletSession, analytics: AnalyticsLogger, transaction: UnconfirmedTransaction, networkService: NetworkService) {
        self.session = session
        self.analytics = analytics
        self.transaction = transaction
        self.networkService = networkService

        let standardConfiguration = TransactionConfigurator.createConfiguration(server: session.server, analytics: analytics, transaction: transaction, account: session.account.address, networkService: networkService)
        self.configurations = .init(standard: standardConfiguration)
    }

    public func updateTransaction(value: BigUInt) {
        let tx = self.transaction
        self.transaction = .init(transactionType: tx.transactionType, value: value, recipient: tx.recipient, contract: tx.contract, data: tx.data, gasLimit: tx.gasLimit, gasPrice: tx.gasPrice, nonce: tx.nonce)
    }

    private func estimateGasLimit() {
        firstly {
            gasLimitEstimator.getGasLimit(value: value, toAddress: toAddress, data: currentConfiguration.data)
        }.done { limit, canCapGasLimit in
            infoLog("Estimated gas limit with eth_estimateGas: \(limit) canCapGasLimit: \(canCapGasLimit)")
            let gasLimit: BigUInt = {
                if limit == GasLimitConfiguration.minGasLimit {
                    return limit
                }
                if canCapGasLimit {
                    return min(limit + (limit * 20 / 100), self.maxGasLimit)
                } else {
                    return limit + (limit * 20 / 100)
                }
            }()
            infoLog("Using gas limit: \(gasLimit)")
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

            self.delegate?.gasLimitEstimateUpdated(to: gasLimit, in: self)
        }.catch { e in
            infoLog("Error estimating gas limit: \(e)")
            logError(e, rpcServer: self.session.server)
        }
    }

    private func estimateGasPrice() {
        gasPriceEstimator
            .estimateGasPrice(server: session.server)
            .sink(receiveCompletion: { [session] result in
                guard case .failure(let e)  = result else { return }
                logError(e, rpcServer: session.server)
            }, receiveValue: { [gasPriceEstimator] estimates in
                let standard = estimates.standard
                var customConfig = self.configurations.custom
                customConfig.setEstimated(gasPrice: standard)
                var defaultConfig = self.configurations.standard
                defaultConfig.setEstimated(gasPrice: standard)
                if gasPriceEstimator.shouldUseEstimatedGasPrice(standard, forTransaction: self.transaction) {
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

                self.delegate?.gasPriceEstimateUpdated(to: standard, in: self)
            }).store(in: &cancelable)
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

    private static func createConfiguration(server: RPCServer, analytics: AnalyticsLogger, transaction: UnconfirmedTransaction, account: AlphaWallet.Address, networkService: NetworkService) -> TransactionConfiguration {
        let maxGasLimit = GasLimitConfiguration.maxGasLimit(forServer: server)
        let gasPrice = GasPriceEstimator(analytics: analytics, networkService: networkService).estimateDefaultGasPrice(server: server, transaction: transaction)
        let gasLimit: BigUInt

        switch transaction.transactionType {
        case .nativeCryptocurrency:
            gasLimit = GasLimitConfiguration.minGasLimit
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
            gasLimit = transaction.gasLimit ?? maxGasLimit
        }

        return TransactionConfiguration(gasPrice: gasPrice, gasLimit: gasLimit, data: transaction.data ?? .init())
    }

    public func start() {
        estimateGasPrice()
        if !isGasLimitSpecifiedByTransaction {
            estimateGasLimit()
        }
        computeNonce()
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
            delegate?.updateNonce(to: nonce, in: self)
        }
    }

    private func computeNonce() {
        if let nonce = transaction.nonce, nonce > 0 {
            useNonce(Int(nonce))
        } else {
            firstly {
                GetNextNonce(server: session.server, wallet: session.account.address, analytics: analytics).getNextNonce()
            }.done {
                self.useNonce($0)
            }.cauterize()
        }
    }

    public func formUnsignedTransaction() -> UnsignedTransaction {
        return UnsignedTransaction(
            value: value,
            account: session.account.address,
            to: toAddress,
            nonce: currentConfiguration.nonce ?? -1,
            data: currentConfiguration.data,
            gasPrice: currentConfiguration.gasPrice,
            gasLimit: currentConfiguration.gasLimit,
            server: session.server,
            transactionType: transaction.transactionType
        )
    }

    public func chooseCustomConfiguration(_ configuration: TransactionConfiguration) {
        configurations.custom = configuration
        selectedConfigurationType = .custom
        delegate?.configurationChanged(in: self)
    }

    public func chooseDefaultConfigurationType(_ configurationType: TransactionConfigurationType) {
        selectedConfigurationType = configurationType
        delegate?.configurationChanged(in: self)
    }
}
