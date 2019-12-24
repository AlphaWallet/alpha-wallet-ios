// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import Result
import TrustKeystore
import JSONRPCKit
import APIKit

public struct PreviewTransaction {
    let value: BigInt
    let account: EthereumAccount
    let address: AlphaWallet.Address?
    let contract: AlphaWallet.Address?
    let nonce: Int
    let data: Data
    let gasPrice: BigInt
    let gasLimit: BigInt
    let transferType: TransferType
}

class TransactionConfigurator {
    private let session: WalletSession
    private let account: EthereumAccount
    private lazy var calculatedGasPrice: BigInt = {
        switch session.server {
        case .xDai:
            //xdai transactions are always 1 gwei in gasPrice
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .custom:
            return configureGasPrice()
        }
    }()

    private func configureGasPrice() -> BigInt {
        if let gasPrice = transaction.gasPrice, gasPrice > 0 {
            return gasPrice
        } else {
            return configuration.gasPrice
        }
    }

    private var requestEstimateGas: Bool {
        return transaction.gasLimit == .none
    }

    let transaction: UnconfirmedTransaction

    var configurationUpdate: Subscribable<TransactionConfiguration> = Subscribable(nil)

    var configuration: TransactionConfiguration {
        didSet {
            configurationUpdate.value = configuration
        }
    }

    init(
        session: WalletSession,
        account: EthereumAccount,
        transaction: UnconfirmedTransaction
    ) {
        self.session = session
        self.account = account
        self.transaction = transaction

        self.configuration = TransactionConfiguration(
            gasPrice: min(max(transaction.gasPrice ?? GasPriceConfiguration.defaultPrice, GasPriceConfiguration.minPrice), GasPriceConfiguration.maxPrice),
            gasLimit: transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit,
            data: transaction.data ?? Data()
        )
    }
    func estimateGasLimit() {
        let to: AlphaWallet.Address? = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp: return transaction.to
            case .ERC20Token(let token, _, _):
                return token.contractAddress
            case .ERC875Token(let token):
                return token.contractAddress
            case .ERC875TokenOrder(let token):
                return token.contractAddress
            case .ERC721Token(let token):
                return token.contractAddress
            case .ERC721ForTicketToken(let token):
                return token.contractAddress
            }
        }()
        let request = EstimateGasRequest(
            from: session.account.address,
            to: to,
            value: transaction.value,
            data: configuration.data
        )
        Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request))) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let gasLimit):
                let gasLimit: BigInt = {
                    let limit = BigInt(gasLimit.drop0x, radix: 16) ?? BigInt()
                    if limit == BigInt(21000) {
                        return limit
                    }
                    return limit + (limit * 20 / 100)
                }()
                strongSelf.configuration =  TransactionConfiguration(
                    gasPrice: strongSelf.calculatedGasPrice,
                    gasLimit: gasLimit,
                    data: strongSelf.configuration.data
                )
            case .failure: break
            }
        }
    }

    func load(completion: @escaping (Result<Void, AnyError>) -> Void) {
        switch transaction.transferType {
        case .nativeCryptocurrency, .dapp:
            guard requestEstimateGas else {
                return completion(.success(()))
            }
            estimateGasLimit()
            configuration = TransactionConfiguration(
                    gasPrice: calculatedGasPrice,
                    gasLimit: GasLimitConfiguration.maxGasLimit,
                    data: transaction.data ?? configuration.data
            )
            completion(.success(()))
        case .ERC20Token:
            do {
                let function = Function(name: "transfer", parameters: [ABIType.address, ABIType.uint(bits: 256)])
                //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
                let parameters: [Any] = [Address(address: transaction.to!), BigUInt(transaction.value)]
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: parameters)
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                completion(.success(()))
            } catch {
                completion(.failure(AnyError(Web3Error(description: "malformed tx"))))
            }
        case .ERC875Token(let token):
            do {
                let parameters: [Any] = [TrustKeystore.Address(address: transaction.to!), transaction.indices!.map({ BigUInt($0) })]
                let arrayType: ABIType
                if token.contractAddress.isLegacy875Contract {
                    arrayType = ABIType.uint(bits: 16)
                } else {
                    arrayType = ABIType.uint(bits: 256)
                }
                let functionEncoder = Function(name: "transfer", parameters: [
                        .address,
                        .dynamicArray(arrayType)
                    ]
                )
                let encoder = ABIEncoder()
                try encoder.encode(function: functionEncoder, arguments: parameters)
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                completion(.success(()))
            } catch {
                completion(.failure(AnyError(Web3Error(description: "malformed tx"))))
            }
        case .ERC875TokenOrder(let token):
            do {
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
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                completion(.success(()))
            } catch {
                completion(.failure(AnyError(Web3Error(description: "malformed tx"))))
            }
        case .ERC721Token(let token), .ERC721ForTicketToken(let token):
            do {
                let function: Function
                let parameters: [Any]
                if token.contractAddress.isLegacy721Contract {
                    function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
                    parameters = [TrustKeystore.Address(address: transaction.to!), BigUInt(transaction.tokenId!)!]
                } else {
                    function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256)])
                    parameters = [TrustKeystore.Address(address: self.account.address), TrustKeystore.Address(address: transaction.to!), BigUInt(transaction.tokenId!)!]
                }
                let encoder = ABIEncoder()
                try encoder.encode(function: function, arguments: parameters)
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                completion(.success(()))
            } catch {
                completion(.failure(AnyError(Web3Error(description: "malformed tx"))))
            }
        }
    }

    func previewTransaction() -> PreviewTransaction {
        return PreviewTransaction(
            value: transaction.value,
            account: account,
            address: transaction.to,
            contract: .none,
            nonce: -1,
            data: configuration.data,
            gasPrice: configuration.gasPrice,
            gasLimit: configuration.gasLimit,
            transferType: transaction.transferType
        )
    }

    func formUnsignedTransaction() -> UnsignedTransaction {
        let value: BigInt = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp: return transaction.value
            case .ERC20Token: return 0
            case .ERC875Token: return 0
            case .ERC875TokenOrder: return transaction.value
            case .ERC721Token: return 0
            case .ERC721ForTicketToken: return 0
            }
        }()
        let address: AlphaWallet.Address? = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp: return transaction.to
            case .ERC20Token(let token, _, _): return token.contractAddress
            case .ERC875Token(let token): return token.contractAddress
            case .ERC875TokenOrder(let token): return token.contractAddress
            case .ERC721Token(let token): return token.contractAddress
            case .ERC721ForTicketToken(let token): return token.contractAddress
            }
        }()
        let signTransaction = UnsignedTransaction(
            value: value,
            account: account,
            to: address,
            nonce: -1,
            data: configuration.data,
            gasPrice: configuration.gasPrice,
            gasLimit: configuration.gasLimit,
            server: session.server
        )

        return signTransaction
    }

    func update(configuration: TransactionConfiguration) {
        self.configuration = configuration
    }
}
