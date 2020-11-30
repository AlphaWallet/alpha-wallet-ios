// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import TrustKeystore

protocol TransactionConfiguratorDelegate: class {
    func configurationChanged(in configurator: TransactionConfigurator)
    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator)
    func updateNonce(to nonce: Int, in configurator: TransactionConfigurator)
}

class TransactionConfigurator {
    private let account: AlphaWallet.Address

    private var isGasLimitSpecifiedByTransaction: Bool {
        transaction.gasLimit != nil
    }

    let session: WalletSession
    weak var delegate: TransactionConfiguratorDelegate?

    let transaction: UnconfirmedTransaction
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

    var toAddress: AlphaWallet.Address? {
        switch transaction.transactionType {
        case .nativeCryptocurrency:
            return transaction.recipient
        case .dapp, .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .tokenScript, .claimPaidErc875MagicLink:
            return transaction.contract
        }
    }

    var value: BigInt {
        //TODO why not all `transaction.value`? Shouldn't the other types of transactions make sure their `transaction.value` is 0?
        switch transaction.transactionType {
        case .nativeCryptocurrency, .dapp: return transaction.value
        case .ERC20Token: return 0
        case .ERC875Token: return 0
        case .ERC875TokenOrder: return transaction.value
        case .ERC721Token: return 0
        case .ERC721ForTicketToken: return 0
        case .tokenScript: return transaction.value
        case .claimPaidErc875MagicLink: return transaction.value
        }
    }

    init(session: WalletSession, transaction: UnconfirmedTransaction) {
        self.session = session
        self.account = session.account.address
        self.transaction = transaction
        self.configurations = .init(standard: TransactionConfigurator.createConfiguration(server: session.server, transaction: transaction, account: account))
    }

    private func estimateGasLimit() {
        guard let toAddress = toAddress else {return}
        let request = EstimateGasRequest(
            from: session.account.address,
            to: toAddress,
            value: value,
            data: currentConfiguration.data
        )

        Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request))) { result in
            switch result {
            case .success(let gasLimit):
                let gasLimit: BigInt = {
                    let limit = BigInt(gasLimit.drop0x, radix: 16) ?? BigInt()
                    if limit == GasLimitConfiguration.minGasLimit {
                        return limit
                    }
                    return min(limit + (limit * 20 / 100), GasLimitConfiguration.maxGasLimit)
                }()
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
            case .failure:
                break
            }
        }
    }

    private func estimateGasPrice() {
        firstly {
            estimateGasPrice(server: session.server)
        }.done { estimates in
            let standard = estimates.standard
            var customConfig = self.configurations.custom
            customConfig.setEstimated(gasPrice: standard)
            self.configurations.custom = customConfig
            var defaultConfig = self.configurations.standard
            defaultConfig.setEstimated(gasPrice: standard)
            self.configurations.standard = defaultConfig

            for each: TransactionConfigurationType  in [.slow, .fast, .rapid] {
                guard let estimate = estimates[each] else { continue }
                //Since there's a price estimate, we want to add that config if it's missing
                var config = self.configurations[each] ?? defaultConfig
                config.setEstimated(gasPrice: estimate)
                self.configurations[each] = config
            }

            self.delegate?.gasPriceEstimateUpdated(to: standard, in: self)
        }.cauterize()
    }

    private func estimateGasPrice(server: RPCServer) -> Promise<GasEstimates> {
        switch server {
        case .main:
            return firstly {
                estimateGasPriceForEthMainnetUsingThirdPartyApi()
            }.recover { error -> Promise<GasEstimates> in
                self.estimateGasPriceForUseRpcNode(server: server)
            }
        case .xDai:
            return estimateGasPriceForXDai()
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom:
            return estimateGasPriceForUseRpcNode(server: server)
        }
    }

    private func estimateGasPriceForEthMainnetUsingThirdPartyApi() -> Promise<GasEstimates> {
        let estimator = GasNowGasPriceEstimator()
        return firstly {
            estimator.fetch()
        }.map { estimates in
            GasEstimates(standard: BigInt(estimates.standard), others: [
                TransactionConfigurationType.slow: BigInt(estimates.slow),
                TransactionConfigurationType.fast: BigInt(estimates.fast),
                TransactionConfigurationType.rapid: BigInt(estimates.rapid)
            ])
        }
    }

    private func estimateGasPriceForXDai() -> Promise<GasEstimates> {
        //xDAI node returns a much higher gas price than necessary so if it is xDAI simply return 1 Gwei
        .value(.init(standard: GasPriceConfiguration.xDaiGasPrice))
    }

    private func estimateGasPriceForUseRpcNode(server: RPCServer) -> Promise<GasEstimates> {
        Promise { seal in
            let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
            Session.send(request) { result in
                switch result {
                case .success(let balance):
                    if let gasPrice = BigInt(balance.drop0x, radix: 16) {
                        if (gasPrice + GasPriceConfiguration.oneGwei) > GasPriceConfiguration.maxPrice {
                            // Guard against really high prices
                            seal.fulfill(.init(standard: GasPriceConfiguration.maxPrice))
                        } else {
                            //Add an extra gwei because the estimate is sometimes too low
                            seal.fulfill(.init(standard: gasPrice + GasPriceConfiguration.oneGwei))
                        }
                    } else {
                        seal.fulfill(.init(standard: GasPriceConfiguration.defaultPrice))
                    }
                case .failure:
                    seal.fulfill(.init(standard: GasPriceConfiguration.defaultPrice))
                }
            }
        }
    }

    private static func computeDefaultGasPrice(server: RPCServer, transaction: UnconfirmedTransaction) -> BigInt {
        switch server {
        case .xDai:
            //xdai transactions are always 1 gwei in gasPrice
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom:
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

    private static func createConfiguration(server: RPCServer, transaction: UnconfirmedTransaction, account: AlphaWallet.Address) -> TransactionConfiguration {
        do {
            switch transaction.transactionType {
            case .dapp:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            case .nativeCryptocurrency:
                return createConfiguration(server: server, transaction: transaction, gasLimit: GasLimitConfiguration.minGasLimit, data: transaction.data ?? .init())
            case .tokenScript:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            case .ERC20Token:
                let function = Function(name: "transfer", parameters: [ABIType.address, ABIType.uint(bits: 256)])
                //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: [Address(address: transaction.recipient!), BigUInt(transaction.value)])
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: encoder.data)
            case .ERC875Token(let token):
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
            case .ERC875TokenOrder(let token):
                let parameters: [Any] = [
                    transaction.expiry!,
                    transaction.indices!.map({ BigUInt($0) }),
                    BigUInt(transaction.v!),
                    Data(hex: transaction.r!),
                    Data(hex: transaction.s!)
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
            case .ERC721Token(let token), .ERC721ForTicketToken(let token):
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
            case .claimPaidErc875MagicLink:
                return createConfiguration(server: server, transaction: transaction, gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, data: transaction.data ?? .init())
            }
        } catch {
            return .init(transaction: transaction)
        }
    }

    func start() {
        estimateGasPrice()
        if !isGasLimitSpecifiedByTransaction {
            estimateGasLimit()
        }
        firstly {
            GetNextNonce(server: session.server, wallet: session.account.address).promise()
        }.done {
            var customConfig = self.configurations.custom
            if let existingNonce = customConfig.nonce, existingNonce > 0 {
                //no-op
            } else {
                customConfig.set(nonce: $0)
                self.configurations.custom = customConfig
                self.delegate?.updateNonce(to: $0, in: self)
            }
        }.cauterize()
    }

    func formUnsignedTransaction() -> UnsignedTransaction {
        UnsignedTransaction(
            value: value,
            account: account,
            to: toAddress,
            nonce: currentConfiguration.nonce ?? -1,
            data: currentConfiguration.data,
            gasPrice: currentConfiguration.gasPrice,
            gasLimit: currentConfiguration.gasLimit,
            server: session.server
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
