// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import Result
import TrustKeystore
import JSONRPCKit
import APIKit
import web3swift

public struct PreviewTransaction {
    let value: BigInt
    let account: Account
    let address: Address?
    let contract: Address?
    let nonce: Int
    let data: Data
    let gasPrice: BigInt
    let gasLimit: BigInt
    let transferType: TransferType
}

class TransactionConfigurator {
    private let session: WalletSession
    private let account: Account
    private lazy var web3: Web3Swift = {
        let result = Web3Swift(url: session.server.rpcURL)
        result.start()
        return result
    }()

    private lazy var calculatedGasPrice: BigInt = {
        switch session.server {
            case .xDai:
                //xdai transactions are always 1 gwei in gasPrice
                return GasPriceConfiguration.xDaiGasPrice
            default:
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
        account: Account,
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
        let to: Address? = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp: return transaction.to
            case .ERC20Token(let token):
                return Address(string: token.contract)
            case .ERC875Token(let token):
                return Address(string: token.contract)
            case .ERC875TokenOrder(let token):
                return Address(string: token.contract)
            case .ERC721Token(let token):
                return Address(string: token.contract)
            }
        }()
        let request = EstimateGasRequest(
            from: session.account.address,
            to: to,
            value: transaction.amount,
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

    func loadTransactionConfiguration(completion: @escaping (Result<Void, AnyError>) -> Void) {
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
            return completion(.success(()))
        case .ERC20Token(_):
            do {
                let encoder = ABIEncoder()
                try encoder.encode(signature: "transfer(address,uint256)")
                try encoder.encode(ABIValue(transaction.to!, type: ABIType.address))
                try encoder.encode(ABIValue(BigUInt(transaction.amount), type: ABIType.uint(bits: 256)))
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                return completion(.success(()))
            } catch {
                return completion(.failure(AnyError(Web3Error(description: ""))))
            }

        case .ERC875Token(let token):
            do {
                let encoder = ABIEncoder()
                if token.contract.isLegacy875Contract {
                    try encoder.encode(signature: "transfer(address,uint16[])")
                    let tokenIndices = try transaction.indices!.map({ BigUInt($0) })
                    let indicesEncoded = try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 16), tokenIndices.count)))
                } else {
                    try encoder.encode(signature: "transfer(address,uint256[])")
                    let tokenIndices = try transaction.indices!.map({ BigUInt($0) })
                    let indicesEncoded = try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 256), tokenIndices.count)))
                }
                let toParam = try encoder.encode(ABIValue(transaction.to!, type: ABIType.address))
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                return completion(.success(()))
            } catch {
                return completion(.failure(AnyError(Web3Error(description: ""))))
            }
        case .ERC875TokenOrder(let token):
            do {
                let encoder = ABIEncoder()
                if token.contract.isLegacy875Contract {
                    try encoder.encode(signature: "trade(uint256,uint16[],uint8,bytes32,bytes32)")
                    let tokenIndices = try transaction.indices!.map({ BigUInt($0) })
                    try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 16), tokenIndices.count)))
                } else {
                    try encoder.encode(signature: "trade(uint256,uint256[],uint8,bytes32,bytes32)")
                    let tokenIndices = try transaction.indices!.map({ BigUInt($0) })
                    try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 256), tokenIndices.count)))
                }
                let v = try encoder.encode(ABIValue(BigUInt(transaction.v!), type: ABIType.uint(bits: 8)))
                let r = try encoder.encode(ABIValue(Data(hexString: transaction.r!)!, type: ABIType.bytes(32)))
                let s = try encoder.encode(ABIValue(Data(hexString: transaction.s!)!, type: ABIType.bytes(32)))
                let expiry = try encoder.encode(ABIValue(transaction.expiry!, type: ABIType.uint(bits: 256)))
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                return completion(.success(()))
            } catch {
                return completion(.failure(AnyError(Web3Error(description: ""))))
            }
        case .ERC721Token(_):
            do {
                let encoder = ABIEncoder()
                try encoder.encode(signature: "transferFrom(address,address,uint256)")
                try encoder.encode(ABIValue(self.session.account.address, type: ABIType.address))
                try encoder.encode(ABIValue(transaction.to!, type: ABIType.address))
                try encoder.encode(ABIValue(BigUInt(transaction.tokenId!, radix: 16)!, type: ABIType.uint(bits: 256)))
                self.configuration = TransactionConfiguration(
                        gasPrice: self.calculatedGasPrice,
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        data: encoder.data
                )
                return completion(.success(()))
            } catch {
                return completion(.failure(AnyError(Web3Error(description: ""))))
            }
        }
    }

    func previewTransaction() -> PreviewTransaction {
        return PreviewTransaction(
            value: transaction.amount,
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
            case .nativeCryptocurrency, .dapp: return transaction.amount
            case .ERC20Token: return 0
            case .ERC875Token: return 0
            case .ERC875TokenOrder: return transaction.amount
            case .ERC721Token: return 0
            }
        }()
        let address: Address? = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp: return transaction.to
            case .ERC20Token(let token): return token.address
            case .ERC875Token(let token): return token.address
            case .ERC875TokenOrder(let token): return token.address
            case .ERC721Token(let token): return token.address
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
