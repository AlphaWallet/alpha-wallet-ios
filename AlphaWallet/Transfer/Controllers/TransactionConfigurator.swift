// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import Result
import TrustKeystore
import JSONRPCKit
import APIKit
import PromiseKit

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
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom:
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

    private var gasLimitNotSet: Bool {
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
            gasLimit: min(transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, GasLimitConfiguration.maxGasLimit),
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
        //TODO transaction.value should only ever be the attached native currency, not the erc20 amount as that is included in the data
        let value: BigInt = {
            switch transaction.transferType {
            case .nativeCryptocurrency, .dapp, .ERC875TokenOrder: return transaction.value
            case .ERC20Token, .ERC721Token, .ERC721ForTicketToken, .ERC875Token:
                return 0;
            }
        }()
        let request = EstimateGasRequest(
            from: session.account.address,
            to: to,
            value: value,
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
                    return min(limit + (limit * 20 / 100), GasLimitConfiguration.maxGasLimit)
                }()
                strongSelf.configuration.gasLimit = gasLimit
            case .failure: break
            }
        }
    }

    func estimateGasPrice() {
        _ = TransactionConfigurator.estimateGasPrice(server: self.session.server).done { [weak self] gasPrice in
            guard let strongSelf = self else { return }
            strongSelf.configuration = TransactionConfiguration(
                    gasPrice: gasPrice,
                    gasLimit: strongSelf.transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit,
                    data: strongSelf.configuration.data,
                    nonce: strongSelf.configuration.nonce
            )
        }
    }

    // Generic function to derive the typical acceptable gas price on each network
    static public func estimateGasPrice(server: RPCServer) -> Promise<BigInt> {
        return Promise { seal in
            if server == .xDai {
                // xDAI node returns a much higher gas price than necessary so if it is xDAI simply return 1 Gwei
                seal.fulfill(GasPriceConfiguration.xDaiGasPrice)
            } else {
                let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
                Session.send(request) { result in
                    switch result {
                    case .success(let balance):
                        if let gasPrice = BigInt(balance.drop0x, radix: 16) {
                            if (gasPrice + GasPriceConfiguration.oneGwei) > GasPriceConfiguration.maxPrice {
                                // Guard against really high prices
                                seal.fulfill(GasPriceConfiguration.maxPrice)
                            } else {
                                //Add an extra gwei because the estimate is sometimes too low
                                seal.fulfill(gasPrice + GasPriceConfiguration.oneGwei)
                            }
                        } else {
                            seal.fulfill(GasPriceConfiguration.defaultPrice)
                        }
                    case .failure:
                        seal.fulfill(GasPriceConfiguration.defaultPrice)
                    }
                }
            }
        }
    }

// swiftlint:disable function_body_length
    func load(completion: @escaping (ResultResult<Void, AnyError>.t) -> Void) {
        switch transaction.transferType {
        case .dapp:
            estimateGasPrice()
            configuration = TransactionConfiguration(
                    gasPrice: calculatedGasPrice,
                    gasLimit: GasLimitConfiguration.maxGasLimit,
                    data: transaction.data ?? configuration.data,
                    nonce: configuration.nonce
            )
            completion(.success(()))
        case .nativeCryptocurrency:
            configuration = TransactionConfiguration(
                    gasPrice: calculatedGasPrice,
                    gasLimit: GasLimitConfiguration.minGasLimit,
                    data: transaction.data ?? configuration.data,
                    nonce: configuration.nonce
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
        /* the node can provide reliable gas limit estimates, this prevents running out of gas or defaulting to an
        inappropriately high gas limit. This can also be an issue for native transfers which are 21k if send to an EOA
        address but may be higher if sent to a contract address. */
        estimateGasLimit()
    }
// swiftlint:enable function_body_length

    func previewTransaction() -> PreviewTransaction {
        return PreviewTransaction(
            value: transaction.value,
            account: account,
            address: transaction.to,
            contract: .none,
                //TODO Can we make these `-1` for nonce be nil instead?
            nonce: configuration.nonce ?? -1,
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
            nonce: configuration.nonce ?? -1,
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
