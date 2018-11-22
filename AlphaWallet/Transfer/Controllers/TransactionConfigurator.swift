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
    private let session: WalletSession
    private let account: Account

    private lazy var calculatedGasPrice: BigInt = {
        return transaction.gasPrice ?? configuration.gasPrice
    }()

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
            gasPrice: min(max(transaction.gasPrice ?? GasPriceConfiguration.default, GasPriceConfiguration.min), GasPriceConfiguration.limit),
            gasLimit: transaction.gasLimit ?? GasPriceConfiguration.limit,
            data: transaction.data ?? Data()
        )
    }
    func estimateGasLimit() {
        let to: Address? = {
            switch transaction.transferType {
            case .ether, .dapp: return transaction.to
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
        case .ether, .dapp:
            guard requestEstimateGas else {
                return completion(.success(()))
            }
            estimateGasLimit()
            configuration = TransactionConfiguration(
                    gasPrice: calculatedGasPrice,
                    gasLimit: GasPriceConfiguration.limit,
                    data: transaction.data ?? configuration.data
            )
            completion(.success(()))
        case .ERC20Token:
            session.web3.request(request: ContractERC20Transfer(amount: transaction.value, address: transaction.to!.description)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: GasPriceConfiguration.limit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
                //TODO clean up
        case .ERC875Token(let token):
            session.web3.request(request: ContractERC875Transfer(
                    address: transaction.to!.description,
                    contractAddress: token.contract,
                    indices: transaction.indices!
            )) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: GasPriceConfiguration.limit,
                            data: data
                    )
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
                //TODO put order claim tx here somehow, or maybe the same one above
        case .ERC875TokenOrder(let token):
            session.web3.request(request: ClaimERC875Order(expiry: transaction.expiry!, indices: transaction.indices!,
                                                           v: transaction.v!, r: transaction.r!, s: transaction.s!, contractAddress: token.contract)) { [unowned self] result in
                switch result {
                case .success(let res):
                    let data = Data(hex: res.drop0x)
                    self.configuration = TransactionConfiguration(
                            gasPrice: self.calculatedGasPrice,
                            gasLimit: GasPriceConfiguration.limit,
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
                            gasLimit: GasPriceConfiguration.limit,
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
            case .ether, .dapp: return transaction.value
            case .ERC20Token: return 0
            case .ERC875Token: return 0
            case .ERC875TokenOrder: return transaction.value
            case .ERC721Token: return 0
            }
        }()
        let address: Address? = {
            switch transaction.transferType {
            case .ether, .dapp: return transaction.to
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
