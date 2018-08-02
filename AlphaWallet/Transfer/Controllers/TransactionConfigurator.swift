// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import Result
import TrustKeystore
import JSONRPCKit
import APIKit

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

    let session: WalletSession
    let account: Account
    let transaction: UnconfirmedTransaction
    var configuration: TransactionConfiguration {
        didSet {
            configurationUpdate.value = configuration
        }
    }

    lazy var calculatedGasPrice: BigInt = {
        return transaction.gasPrice ?? configuration.gasPrice
    }()

    var calculatedGasLimit: BigInt? {
        return transaction.gasLimit
    }

    var requestEstimateGas: Bool {
        return transaction.gasLimit == .none
    }

    var configurationUpdate: Subscribable<TransactionConfiguration> = Subscribable(nil)

    init(
        session: WalletSession,
        account: Account,
        transaction: UnconfirmedTransaction
    ) {
        self.session = session
        self.account = account
        self.transaction = transaction

        self.configuration = TransactionConfiguration(
            gasPrice: min(max(transaction.gasPrice ?? GasPriceConfiguration.default, GasPriceConfiguration.min), GasPriceConfiguration.max),
            gasLimit: transaction.gasLimit ?? GasLimitConfiguration.default,
            data: transaction.data ?? Data()
        )
    }
    func estimateGasLimit() {
        let to: Address? = {
            switch transaction.transferType {
            case .ether: return transaction.to
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
            value: transaction.value,
            data: configuration.data
        )
        Session.send(EtherServiceRequest(batch: BatchFactory().create(request))) { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let gasLimit):
                let gasLimit: BigInt = {
                    let limit = BigInt(gasLimit.drop0x, radix: 16) ?? BigInt()
                    if limit == BigInt(21000) {
                        return limit
                    }
                    return limit + (limit * 20 / 100)
                }()
                self.configuration =  TransactionConfiguration(
                    gasPrice: self.calculatedGasPrice,
                    gasLimit: gasLimit,
                    data: self.configuration.data
                )
            case .failure: break
            }
        }
    }

    func load(completion: @escaping (Result<Void, AnyError>) -> Void) {
        switch transaction.transferType {
        case .ether:
            guard requestEstimateGas else {
                return completion(.success(()))
            }
            estimateGasLimit()
            self.configuration = TransactionConfiguration(
                    gasPrice: calculatedGasPrice,
                    gasLimit: GasLimitConfiguration.default,
                    data: transaction.data ?? self.configuration.data
            )
            completion(.success(()))
        case .ERC20Token:
            session.web3.request(request: ContractERC20Transfer(amount: transaction.value, address: transaction.to!.description)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: Constants.gasLimit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
                //TODO clean up
        case .ERC875Token:
            session.web3.request(request: ContractERC875Transfer(address: transaction.to!.description, indices: (transaction.indices)!)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: Constants.gasLimit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
                //TODO put order claim tx here somehow, or maybe the same one above
        case .ERC875TokenOrder:
            session.web3.request(request: ClaimERC875Order(expiry: transaction.expiry!, indices: transaction.indices!,
                    v: transaction.v!, r: transaction.r!, s: transaction.s!)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: Constants.gasLimit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }

        case .ERC721Token:
            session.web3.request(request: ContractERC721Transfer(address: transaction.to!.description,
                    tokenId: transaction.tokenId!)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: Constants.gasLimit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
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
            case .ether: return transaction.value
            case .ERC20Token: return 0
            case .ERC875Token: return 0
            case .ERC875TokenOrder: return transaction.value
            case .ERC721Token: return 0
            }
        }()
        let address: Address? = {
            switch transaction.transferType {
            case .ether: return transaction.to
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
            chainID: session.config.chainID
        )

        return signTransaction
    }

    func update(configuration: TransactionConfiguration) {
        self.configuration = configuration
    }
}
