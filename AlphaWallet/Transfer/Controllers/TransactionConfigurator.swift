// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import TrustKeystore

protocol TransactionConfiguratorDelegate: AnyObject {
    func configurationChanged(in configurator: TransactionConfigurator)
    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func updateNonce(to nonce: Int, in configurator: TransactionConfigurator)
}

// swiftlint:disable type_body_length
class TransactionConfigurator {
    enum GasPriceWarning {
        case tooHighCustomGasPrice
        case networkCongested
        case tooLowCustomGasPrice

        var shortTitle: String {
            switch self {
            case .tooHighCustomGasPrice, .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceTooHighShort()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowShort()
            }
        }

        var longTitle: String {
            switch self {
            case .tooHighCustomGasPrice, .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceTooHighLong()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowLong()
            }
        }

        var description: String {
            switch self {
            case .tooHighCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooHighDescription()
            case .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceCongestedDescription()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowDescription()
            }
        }
    }

    enum GasLimitWarning {
        case tooHighCustomGasLimit

        var description: String {
            ConfigureTransactionError.gasLimitTooHigh.localizedDescription
        }
    }

    enum GasFeeWarning {
        case tooHighGasFee

        var description: String {
            ConfigureTransactionError.gasFeeTooHigh.localizedDescription
        }
    }

    private let account: AlphaWallet.Address

    private var isGasLimitSpecifiedByTransaction: Bool {
        transaction.gasLimit != nil
    }

    let session: WalletSession
    weak var delegate: TransactionConfiguratorDelegate?

    var transaction: UnconfirmedTransaction
    var selectedConfigurationType: TransactionConfigurationType = .standard
    var configurations: TransactionConfigurations

    var currentConfiguration: TransactionConfiguration {
        switch selectedConfigurationType {
        case .standard:
            return configurations.standard
        case .slow, .fast, .rapid:
            return configurations[selectedConfigurationType]!
        case .custom:
            return configurations.custom
        }
    }

    var gasValue: BigInt {
        return currentConfiguration.gasPrice * currentConfiguration.gasLimit
    }

    var toAddress: AlphaWallet.Address? {
        switch transaction.transactionType {
        case .nativeCryptocurrency:
            return transaction.recipient
        case .dapp, .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink:
            return transaction.contract
        }
    }

    var value: BigInt {
        //TODO why not all `transaction.value`? Shouldn't the other types of transactions make sure their `transaction.value` is 0?
        switch transaction.transactionType {
        case .nativeCryptocurrency, .dapp: return transaction.value
        case .erc20Token: return 0
        case .erc875Token: return 0
        case .erc875TokenOrder: return transaction.value
        case .erc721Token: return 0
        case .erc721ForTicketToken: return 0
        case .erc1155Token: return 0
        case .tokenScript: return transaction.value
        case .claimPaidErc875MagicLink: return transaction.value
        }
    }

    var gasPriceWarning: GasPriceWarning? {
        gasPriceWarning(forConfiguration: currentConfiguration)
    }

    init(session: WalletSession, transaction: UnconfirmedTransaction) {
        self.session = session
        self.account = session.account.address
        self.transaction = transaction
        self.configurations = .init(standard: TransactionConfigurator.createConfiguration(server: session.server, transaction: transaction, account: account))
    }

    func updateTransaction(value: BigInt) {
        let tx = self.transaction
        self.transaction = .init(transactionType: tx.transactionType, value: value, recipient: tx.recipient, contract: tx.contract, data: tx.data, tokenId: tx.tokenId, tokenIdsAndValues: tx.tokenIdsAndValues, indices: tx.indices, gasLimit: tx.gasLimit, gasPrice: tx.gasPrice, nonce: tx.nonce)
    }

    private func estimateGasLimit() {
        let transactionType: EstimateGasRequest.TransactionType
        if let toAddress = toAddress {
            transactionType = .normal(to: toAddress)
        } else {
            transactionType = .contractDeployment
        }
        let request = EstimateGasRequest(
            from: session.account.address,
            transactionType: transactionType,
            value: value,
            data: currentConfiguration.data
        )

        firstly {
            Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request)))
        }.done { gasLimit in
            info("Estimated gas limit with eth_estimateGas: \(gasLimit)")
            let gasLimit: BigInt = {
                let limit = BigInt(gasLimit.drop0x, radix: 16) ?? BigInt()
                if limit == GasLimitConfiguration.minGasLimit {
                    return limit
                }
                return min(limit + (limit * 20 / 100), GasLimitConfiguration.maxGasLimit)
            }()
            info("Using gas limit: \(gasLimit)")
            var customConfig = self.configurations.custom
            customConfig.setEstimated(gasLimit: gasLimit)
            self.configurations.custom = customConfig
            var defaultConfig = self.configurations.standard
            defaultConfig.setEstimated(gasLimit: gasLimit)
            self.configurations.standard = defaultConfig

            //Careful to not create if they don't exist
            for each: TransactionConfigurationType  in [.slow, .fast, .rapid] {
                if var config = self.configurations[each] {
                    config.setEstimated(gasLimit: gasLimit)
                    self.configurations[each] = config
                }
            }

            self.delegate?.gasLimitEstimateUpdated(to: gasLimit, in: self)
        }.catch { e in
            info("Error estimating gas limit: \(e)")
            error(value: e, rpcServer: self.session.server)
        }
    }

    private func estimateGasPrice() {
        firstly {
            Self.estimateGasPrice(server: session.server)
        }.done { estimates in
            let standard = estimates.standard
            var customConfig = self.configurations.custom
            customConfig.setEstimated(gasPrice: standard)
            var defaultConfig = self.configurations.standard
            defaultConfig.setEstimated(gasPrice: standard)
            if self.shouldUseEstimatedGasPrice(standard) {
                self.configurations.custom = customConfig
                self.configurations.standard = defaultConfig
            }

            for each: TransactionConfigurationType  in [.slow, .fast, .rapid] {
                guard let estimate = estimates[each] else { continue }
                //Since there's a price estimate, we want to add that config if it's missing
                var config = self.configurations[each] ?? defaultConfig
                config.setEstimated(gasPrice: estimate)
                self.configurations[each] = config
            }

            self.delegate?.gasPriceEstimateUpdated(to: standard, in: self)
        }.catch({ e in
            error(value: e, rpcServer: self.session.server)
        })
    }

    private func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigInt) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    static func estimateGasPrice(server: RPCServer) -> Promise<GasEstimates> {
        if EtherscanGasPriceEstimator.supports(server: server) {
            return estimateGasPriceForUsingEtherscanApi(server: server).recover { _ in
                estimateGasPriceForUseRpcNode(server: server)
            }
        } else {
            switch server {
            case .xDai:
                return estimateGasPriceForXDai()
            case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
                return Promise(estimateGasPriceForUseRpcNode(server: server))
            }
        }
    }

    private static func estimateGasPriceForUsingEtherscanApi(server: RPCServer) -> Promise<GasEstimates> {
        let estimator = EtherscanGasPriceEstimator()
        return firstly {
            estimator.fetch(server: server)
        }.map { estimates in
            GasEstimates(standard: BigInt(estimates.standard), others: [
                TransactionConfigurationType.slow: BigInt(estimates.slow),
                TransactionConfigurationType.fast: BigInt(estimates.fast),
                TransactionConfigurationType.rapid: BigInt(estimates.rapid)
            ])
        }
    }

    private static func estimateGasPriceForXDai() -> Promise<GasEstimates> {
        //xDAI node returns a much higher gas price than necessary so if it is xDAI simply return 1 Gwei
        .value(.init(standard: GasPriceConfiguration.xDaiGasPrice))
    }

    private static func estimateGasPriceForUseRpcNode(server: RPCServer) -> Guarantee<GasEstimates> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
        return firstly {
            Session.send(request)
        }.map {
            if let gasPrice = BigInt($0.drop0x, radix: 16) {
                if (gasPrice + GasPriceConfiguration.oneGwei) > GasPriceConfiguration.maxPrice {
                    // Guard against really high prices
                    return GasEstimates(standard: GasPriceConfiguration.maxPrice)
                } else {
                    if server.canUserChangeGas {
                        //Add an extra gwei because the estimate is sometimes too low
                        return GasEstimates(standard: gasPrice + GasPriceConfiguration.oneGwei)
                    } else {
                        return GasEstimates(standard: gasPrice)
                    }
                }
            } else {
                return GasEstimates(standard: GasPriceConfiguration.defaultPrice)
            }
        }.recover { _ in
            .value(GasEstimates(standard: GasPriceConfiguration.defaultPrice))
        }
    }

    func gasLimitWarning(forConfiguration configuration: TransactionConfiguration) -> GasLimitWarning? {
        if configuration.gasLimit > ConfigureTransaction.gasLimitMax {
            return .tooHighCustomGasLimit
        }
        return nil
    }

    func gasFeeWarning(forConfiguration configuration: TransactionConfiguration) -> GasFeeWarning? {
        if (configuration.gasPrice * configuration.gasLimit) > ConfigureTransaction.gasFeeMax {
            return .tooHighGasFee
        }
        return nil
    }

    func gasPriceWarning(forConfiguration configuration: TransactionConfiguration) -> GasPriceWarning? {
        if let fastestConfig = configurations.fastestThirdPartyConfiguration, configuration.gasPrice > fastestConfig.gasPrice {
            return .tooHighCustomGasPrice
        }
        //Conversion to gwei is needed so we that 17 (entered) is equal to 17.1 (fetched). Because 17.1 is displayed as "17" in the UI and might confuse the user if it's not treated as equal
        if let slowestConfig = configurations.slowestThirdPartyConfiguration, (configuration.gasPrice / BigInt(EthereumUnit.gwei.rawValue)) < (slowestConfig.gasPrice / BigInt(EthereumUnit.gwei.rawValue)) {
            return .tooLowCustomGasPrice
        }
        switch session.server {
        case .main:
            //NOTE: Suppose that these lines were related to GasNow
            //if (configurations.standard.gasPrice / BigInt(EthereumUnit.gwei.rawValue)) > Constants.highStandardGasThresholdGwei {
            //    return .networkCongested
            //}
            break
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .fantom, .fantom_testnet, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            break
        }
        return nil
    }

    private static func computeDefaultGasPrice(server: RPCServer, transaction: UnconfirmedTransaction) -> BigInt {
        switch server {
        case .xDai:
            //xdai transactions are always 1 gwei in gasPrice
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            if let gasPrice = transaction.gasPrice, gasPrice > 0 {
                return min(max(gasPrice, GasPriceConfiguration.minPrice), GasPriceConfiguration.maxPrice)
            } else {
                let defaultGasPrice = min(max(transaction.gasPrice ?? GasPriceConfiguration.defaultPrice, GasPriceConfiguration.minPrice), GasPriceConfiguration.maxPrice)
                return defaultGasPrice
            }
        }
    }

    private static func createConfiguration(server: RPCServer, transaction: UnconfirmedTransaction, gasLimit: BigInt, data: Data) -> TransactionConfiguration {
        TransactionConfiguration(gasPrice: TransactionConfigurator.computeDefaultGasPrice(server: server, transaction: transaction), gasLimit: gasLimit, data: data)
    }

// swiftlint:disable function_body_length
    private static func createConfiguration(server: RPCServer, transaction: UnconfirmedTransaction, account: AlphaWallet.Address) -> TransactionConfiguration {
        do {
            switch transaction.transactionType {
            case .dapp:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            case .nativeCryptocurrency:
                return createConfiguration(server: server, transaction: transaction, gasLimit: GasLimitConfiguration.minGasLimit, data: transaction.data ?? .init())
            case .tokenScript:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            case .erc20Token:
                let function = Function(name: "transfer", parameters: [ABIType.address, ABIType.uint(bits: 256)])
                //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: [Address(address: transaction.recipient!), BigUInt(transaction.value)])
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
            case .erc875Token(let token, _):
                let parameters: [Any] = [TrustKeystore.Address(address: transaction.recipient!), transaction.indices!.map({ BigUInt($0) })]
                let arrayType: ABIType
                if token.contractAddress.isLegacy875Contract {
                    arrayType = ABIType.uint(bits: 16)
                } else {
                    arrayType = ABIType.uint(bits: 256)
                }
                let functionEncoder = Function(name: "transfer", parameters: [.address, .dynamicArray(arrayType)])
                let encoder = ABIEncoder()
                try encoder.encode(function: functionEncoder, arguments: parameters)
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
            case .erc875TokenOrder(let token, _):
                let parameters: [Any] = [
                    transaction.expiry!,
                    transaction.indices!.map({ BigUInt($0) }),
                    BigUInt(transaction.v!),
                    Data(_hex: transaction.r!),
                    Data(_hex: transaction.s!)
                ]

                let arrayType: ABIType
                if token.contractAddress.isLegacy875Contract {
                    arrayType = ABIType.uint(bits: 16)
                } else {
                    arrayType = ABIType.uint(bits: 256)
                }

                let functionEncoder = Function(name: "trade", parameters: [
                    .uint(bits: 256),
                    .dynamicArray(arrayType),
                    .uint(bits: 8),
                    .bytes(32),
                    .bytes(32)
                ])
                let encoder = ABIEncoder()
                try encoder.encode(function: functionEncoder, arguments: parameters)
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
            case .erc721Token(let token, _), .erc721ForTicketToken(let token, _):
                let function: Function
                let parameters: [Any]

                if token.contractAddress.isLegacy721Contract {
                    function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
                    parameters = [
                        TrustKeystore.Address(address: transaction.recipient!), transaction.tokenId!
                    ]
                } else {
                    function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256)])
                    parameters = [
                        TrustKeystore.Address(address: account),
                        TrustKeystore.Address(address: transaction.recipient!),
                        transaction.tokenId!
                    ]
                }
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: parameters)
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
            case .erc1155Token(_, let transferType, _):
                switch transferType {
                case .singleTransfer:
                    let function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256), .uint(bits: 256), .dynamicBytes])
                    let parameters: [Any] = [
                        TrustKeystore.Address(address: account),
                        TrustKeystore.Address(address: transaction.recipient!),
                        transaction.tokenIdsAndValues![0].tokenId,
                        transaction.tokenIdsAndValues![0].value,
                        Data()
                    ]
                    let encoder = ABIEncoder()
                    try encoder.encode(function: function, arguments: parameters)
                    return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
                case .batchTransfer:
                    let tokenIds = transaction.tokenIdsAndValues!.compactMap { $0.tokenId }
                    let values = transaction.tokenIdsAndValues!.compactMap { $0.value }
                    let function = Function(name: "safeBatchTransferFrom", parameters: [
                        .address,
                        .address,
                        .array(.uint(bits: 256), tokenIds.count),
                        .array(.uint(bits: 256), values.count),
                        .dynamicBytes
                    ])

                    let parameters: [Any] = [
                        TrustKeystore.Address(address: account),
                        TrustKeystore.Address(address: transaction.recipient!),
                        tokenIds,
                        values,
                        Data()
                    ]
                    let encoder = ABIEncoder()
                    try encoder.encode(function: function, arguments: parameters)
                    return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
                }
            case .claimPaidErc875MagicLink:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            }
        } catch {
            return .init(transaction: transaction)
        }
    }
// swiftlint:enable function_body_length

    func start() {
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

            for each: TransactionConfigurationType  in [.slow, .fast, .rapid] {
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
                GetNextNonce(server: session.server, wallet: session.account.address).promise()
            }.done {
                self.useNonce($0)
            }.cauterize()
        }
    }

    func formUnsignedTransaction() -> UnsignedTransaction {
        return UnsignedTransaction(
            value: value,
            account: account,
            to: toAddress,
            nonce: currentConfiguration.nonce ?? -1,
            data: currentConfiguration.data,
            gasPrice: currentConfiguration.gasPrice,
            gasLimit: currentConfiguration.gasLimit,
            server: session.server,
            transactionType: transaction.transactionType
        )
    }

    func chooseCustomConfiguration(_ configuration: TransactionConfiguration) {
        configurations.custom = configuration
        selectedConfigurationType = .custom
        delegate?.configurationChanged(in: self)
    }

    func chooseDefaultConfigurationType(_ configurationType: TransactionConfigurationType) {
        selectedConfigurationType = configurationType
        delegate?.configurationChanged(in: self)
    }
}
// swiftlint:enable type_body_length
