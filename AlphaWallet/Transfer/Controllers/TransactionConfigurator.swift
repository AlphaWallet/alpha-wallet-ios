// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit

protocol TransactionConfiguratorDelegate: AnyObject {
    func configurationChanged(in configurator: TransactionConfigurator)
    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func updateNonce(to nonce: Int, in configurator: TransactionConfigurator)
}

enum TransactionConfiguratorError: Error {
    case impossibleToBuildConfiguration
    
    var localizedDescription: String {
        return "Impossible To Build Configuration"
    }
}

class TransactionConfigurator {

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

    private var maxGasLimit: BigInt {
        GasLimitConfiguration.maxGasLimit(forServer: session.server)
    }

    var toAddress: AlphaWallet.Address? {
        switch transaction.transactionType {
        case .nativeCryptocurrency:
            return transaction.recipient
        case .dapp, .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
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
        case .prebuilt: return transaction.value
        }
    }

    var gasPriceWarning: GasPriceWarning? {
        gasPriceWarning(forConfiguration: currentConfiguration)
    }

    init(session: WalletSession, transaction: UnconfirmedTransaction) throws {
        self.session = session
        self.transaction = transaction

        let standardConfiguration = try TransactionConfigurator.createConfiguration(server: session.server, transaction: transaction, account: session.account.address)
        self.configurations = .init(standard: standardConfiguration)
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
            infoLog("Estimated gas limit with eth_estimateGas: \(gasLimit)")
            let gasLimit: BigInt = {
                let limit = BigInt(gasLimit.drop0x, radix: 16) ?? BigInt()
                if limit == GasLimitConfiguration.minGasLimit {
                    return limit
                }
                return min(limit + (limit * 20 / 100), self.maxGasLimit)
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
            error(value: e, rpcServer: self.session.server)
        }
    }

    private func estimateGasPrice() {
        let estimator = GasPriceEstimator()
        firstly {
            estimator.estimateGasPrice(server: session.server)
        }.done { estimates in
            let standard = estimates.standard
            var customConfig = self.configurations.custom
            customConfig.setEstimated(gasPrice: standard)
            var defaultConfig = self.configurations.standard
            defaultConfig.setEstimated(gasPrice: standard)
            if estimator.shouldUseEstimatedGasPrice(standard, forTransaction: self.transaction) {
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
        }.catch({ e in
            error(value: e, rpcServer: self.session.server)
        })
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
            if (configurations.standard.gasPrice / BigInt(EthereumUnit.gwei.rawValue)) > Constants.highStandardEthereumMainnetGasThresholdGwei {
                return .networkCongested
            }
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .fantom, .fantom_testnet, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet:
            break
        }
        return nil
    } 

    private static func createConfiguration(server: RPCServer, transaction: UnconfirmedTransaction, gasLimit: BigInt, data: Data) -> TransactionConfiguration {
        let gasPrice = GasPriceEstimator().estimateDefaultGasPrice(server: server, transaction: transaction)
        return TransactionConfiguration(gasPrice: gasPrice, gasLimit: gasLimit, data: data)
    }

// swiftlint:disable function_body_length
    private static func createConfiguration(server: RPCServer, transaction: UnconfirmedTransaction, account: AlphaWallet.Address) throws -> TransactionConfiguration {
        let maxGasLimit = GasLimitConfiguration.maxGasLimit(forServer: server)
        do {
            switch transaction.transactionType {
            case .dapp:
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: transaction.data ?? .init())
            case .nativeCryptocurrency:
                let gasLimit = GasLimitConfiguration.minGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: transaction.data ?? .init())
            case .tokenScript:
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: transaction.data ?? .init())
            case .erc20Token:
                guard let recipient = transaction.recipient else {
                    throw TransactionConfiguratorError.impossibleToBuildConfiguration
                }
                let function = Function(name: "transfer", parameters: [ABIType.address, ABIType.uint(bits: 256)])
                //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: [recipient, BigUInt(transaction.value)])
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
            case .erc875Token(let token, _):
                guard let recipient = transaction.recipient, let indices = transaction.indices else {
                    throw TransactionConfiguratorError.impossibleToBuildConfiguration
                }
                let parameters: [Any] = [recipient, indices.map({ BigUInt($0) })]
                let arrayType: ABIType
                if token.contractAddress.isLegacy875Contract {
                    arrayType = ABIType.uint(bits: 16)
                } else {
                    arrayType = ABIType.uint(bits: 256)
                }
                let functionEncoder = Function(name: "transfer", parameters: [.address, .dynamicArray(arrayType)])
                let encoder = ABIEncoder()
                try encoder.encode(function: functionEncoder, arguments: parameters)
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
            case .erc875TokenOrder(let token, _):
                guard let expiry = transaction.expiry, let indices = transaction.indices, let v = transaction.v, let r = transaction.r, let s = transaction.s else {
                    throw TransactionConfiguratorError.impossibleToBuildConfiguration
                }
                let parameters: [Any] = [
                    expiry,
                    indices.map({ BigUInt($0) }),
                    BigUInt(v),
                    Data(_hex: r),
                    Data(_hex: s)
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
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
            case .erc721Token(let token, _), .erc721ForTicketToken(let token, _):
                guard let recipient = transaction.recipient, let tokenId = transaction.tokenId else {
                    throw TransactionConfiguratorError.impossibleToBuildConfiguration
                }

                let function: Function
                let parameters: [Any]

                if token.contractAddress.isLegacy721Contract {
                    function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
                    parameters = [recipient, tokenId]
                } else {
                    function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256)])
                    parameters = [account, recipient, tokenId]
                }
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: parameters)
                let gasLimit = transaction.gasLimit ?? maxGasLimit

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
            case .erc1155Token(_, let transferType, _):
                guard let recipient = transaction.recipient, let tokenIdAndValue = transaction.tokenIdsAndValues?.first else {
                    throw TransactionConfiguratorError.impossibleToBuildConfiguration
                }
                switch transferType {
                case .singleTransfer:
                    let function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256), .uint(bits: 256), .dynamicBytes])
                    let parameters: [Any] = [
                        account,
                        recipient,
                        tokenIdAndValue.tokenId,
                        tokenIdAndValue.value,
                        Data()
                    ]
                    let encoder = ABIEncoder()
                    try encoder.encode(function: function, arguments: parameters)
                    let gasLimit = transaction.gasLimit ?? maxGasLimit

                    return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
                case .batchTransfer:
                    guard let recipient = transaction.recipient, let tokenIdsAndValues = transaction.tokenIdsAndValues else {
                        throw TransactionConfiguratorError.impossibleToBuildConfiguration
                    }
                    let tokenIds = tokenIdsAndValues.compactMap { $0.tokenId }
                    let values = tokenIdsAndValues.compactMap { $0.value }
                    let function = Function(name: "safeBatchTransferFrom", parameters: [
                        .address,
                        .address,
                        .array(.uint(bits: 256), tokenIds.count),
                        .array(.uint(bits: 256), values.count),
                        .dynamicBytes
                    ])

                    let parameters: [Any] = [
                        account,
                        recipient,
                        tokenIds,
                        values,
                        Data()
                    ]
                    let encoder = ABIEncoder()
                    try encoder.encode(function: function, arguments: parameters)
                    let gasLimit = transaction.gasLimit ?? maxGasLimit

                    return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: encoder.data)
                }
            case .claimPaidErc875MagicLink:
                let gasLimit = transaction.gasLimit ?? maxGasLimit
                let data = transaction.data ?? .init()

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: data)
            case .prebuilt:
                let gasLimit = transaction.gasLimit ?? maxGasLimit
                let data = transaction.data ?? .init()

                return createConfiguration(server: server, transaction: transaction, gasLimit: gasLimit, data: data)
            }
        } catch {
            if case TransactionConfiguratorError.impossibleToBuildConfiguration = error {
                throw error
            }
            return .init(transaction: transaction, server: server)
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
                GetNextNonce(server: session.server, wallet: session.account.address).promise()
            }.done {
                self.useNonce($0)
            }.cauterize()
        }
    }

    func formUnsignedTransaction() -> UnsignedTransaction {
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
