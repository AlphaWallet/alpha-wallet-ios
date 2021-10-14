//
//  TokenProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.08.2021.
//

import PromiseKit
import Result
import BigInt

// NOTE: Think about the name, more fittable name is needed
protocol TokenProviderType: class {
    func getContractName(for address: AlphaWallet.Address, completion: @escaping (ResultResult<String, AnyError>.t) -> Void)
    func getContractSymbol(for address: AlphaWallet.Address, completion: @escaping (ResultResult<String, AnyError>.t) -> Void)
    func getDecimals(for address: AlphaWallet.Address, completion: @escaping (ResultResult<UInt8, AnyError>.t) -> Void)
    func getContractName(for address: AlphaWallet.Address) -> Promise<String>
    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String>
    func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8>
    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType>
    func getERC20Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void)
    func getERC875Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void)
    func getERC721ForTicketsBalance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void)
    func getERC721Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void)
    func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance>
    func getERC20Balance(for address: AlphaWallet.Address) -> Promise<BigInt>
    func getERC875Balance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getERC721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getERC721Balance(for address: AlphaWallet.Address) -> Promise<[String]>
}

class TokenProvider: TokenProviderType {
    static let fetchContractDataTimeout = TimeInterval(4)

    private lazy var getNameCoordinator: GetNameCoordinator = {
        return GetNameCoordinator(forServer: server)
    }()

    private lazy var getSymbolCoordinator: GetSymbolCoordinator = {
        return GetSymbolCoordinator(forServer: server)
    }()

    private lazy var getNativeCryptoCurrencyBalanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator = {
        return GetNativeCryptoCurrencyBalanceCoordinator(forServer: server, queue: queue)
    }()

    private lazy var getERC20BalanceCoordinator: GetERC20BalanceCoordinator = {
        return GetERC20BalanceCoordinator(forServer: server, queue: queue)
    }()

    private lazy var getERC875BalanceCoordinator: GetERC875BalanceCoordinator = {
        return GetERC875BalanceCoordinator(forServer: server, queue: queue)
    }()

    private lazy var getERC721ForTicketsBalanceCoordinator: GetERC721ForTicketsBalanceCoordinator = {
        return GetERC721ForTicketsBalanceCoordinator(forServer: server, queue: queue)
    }()

    private lazy var getIsERC875ContractCoordinator: GetIsERC875ContractCoordinator = {
        return GetIsERC875ContractCoordinator(forServer: server)
    }()

    private lazy var getERC721BalanceCoordinator: GetERC721BalanceCoordinator = {
        return GetERC721BalanceCoordinator(forServer: server, queue: queue)
    }()

    private lazy var getIsERC721ForTicketsContractCoordinator: GetIsERC721ForTicketsContractCoordinator = {
        return GetIsERC721ForTicketsContractCoordinator(forServer: server)
    }()

    private lazy var getIsERC721ContractCoordinator: GetIsERC721ContractCoordinator = {
        return GetIsERC721ContractCoordinator(forServer: server)
    }()

    private lazy var getIsERC1155ContractCoordinator: GetIsERC1155ContractCoordinator = {
        return GetIsERC1155ContractCoordinator(forServer: server)
    }()

    private lazy var getDecimalsCoordinator: GetDecimalsCoordinator = {
        return GetDecimalsCoordinator(forServer: server)
    }()

    private let account: Wallet
    private let numberOfTimesToRetryFetchContractData = 2
    private let server: RPCServer
    private let queue: DispatchQueue?

    init(account: Wallet, server: RPCServer, queue: DispatchQueue? = .none) {
        self.account = account
        self.queue = queue
        self.server = server
    }

    func getContractName(for address: AlphaWallet.Address,
                         completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getNameCoordinator.getName(for: address) { (result) in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        getNativeCryptoCurrencyBalanceCoordinator.getBalance(for: address)
    }

    func getContractSymbol(for address: AlphaWallet.Address,
                           completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getSymbolCoordinator.getSymbol(for: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getDecimals(for address: AlphaWallet.Address,
                     completion: @escaping (ResultResult<UInt8, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getDecimalsCoordinator.getDecimals(for: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        Promise { seal in
            getContractName(for: address) { (result) in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String> {
        Promise { seal in
            getContractSymbol(for: address) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8> {
        Promise { seal in
            getDecimals(for: address) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType> {
        Promise { seal in
            getTokenType(for: address) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }

    func getERC20Balance(for address: AlphaWallet.Address) -> Promise<BigInt> {
        Promise { seal in
            getERC20Balance(for: address) { result in
                switch result {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getERC20Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC20BalanceCoordinator.getBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getERC875Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            getERC875Balance(for: address) { result in
                switch result {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getERC875Balance(for address: AlphaWallet.Address,
                          completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC875BalanceCoordinator.getERC875TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getERC721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            getERC721ForTicketsBalance(for: address) { result in
                switch result {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getERC721ForTicketsBalance(for address: AlphaWallet.Address,
                                    completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721ForTicketsBalanceCoordinator.getERC721ForTicketsTokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getERC721Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            getERC721Balance(for: address) { result in
                switch result {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    //TODO should callers call tokenURI and so on, instead?
    func getERC721Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721BalanceCoordinator.getERC721TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success(let balance):
                    if balance >= Int.max {
                        completion(.failure(AnyError(Web3Error(description: ""))))
                    } else {
                        completion(.success([String](repeating: "0", count: Int(balance))))
                    }
                case .failure(let error):
                    if !triggerRetry() {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

// swiftlint:disable function_body_length
    private func getTokenType(for address: AlphaWallet.Address, completion: @escaping (TokenType) -> Void) {
        let isErc875Promise = Promise<Bool> { seal in
            withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
                guard let strongSelf = self else { return }
                //Function hash is "0x4f452b9a". This might cause many "execution reverted" RPC errors
                //TODO rewrite flow so we reduce checks for this as it causes too many "execution reverted" RPC errors and looks scary when we look in Charles proxy. Maybe check for ERC20 (via EIP165) as well as ERC721 in parallel first, then fallback to this ERC875 check
                strongSelf.getIsERC875ContractCoordinator.getIsERC875Contract(for: address) { [weak self] result in
                    guard self != nil else { return }
                    switch result {
                    case .success(let isERC875):
                        if isERC875 {
                            seal.fulfill(true)
                        } else {
                            seal.fulfill(false)
                        }
                    case .failure:
                        if !triggerRetry() {
                            seal.fulfill(false)
                        }
                    }
                }
            }
        }
        enum Erc721Type {
            case erc721
            case erc721ForTickets
            case notErc721
        }
        let isErc721Promise = Promise<Erc721Type> { seal in
            withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
                guard let strongSelf = self else { return }
                strongSelf.getIsERC721ContractCoordinator.getIsERC721Contract(for: address) { [weak self] result in
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let isERC721):
                        if isERC721 {
                            withRetry(times: strongSelf.numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry2 in
                                guard let strongSelf = self else { return }
                                strongSelf.getIsERC721ForTicketsContractCoordinator.getIsERC721ForTicketContract(for: address) { result in
                                    switch result {
                                    case .success(let isERC721ForTickets):
                                        if isERC721ForTickets {
                                            seal.fulfill(.erc721ForTickets)
                                        } else {
                                            seal.fulfill(.erc721)
                                        }
                                    case .failure:
                                        if !triggerRetry2() {
                                            seal.fulfill(.erc721)
                                        }
                                    }
                                }
                            }
                        } else {
                            seal.fulfill(.notErc721)
                        }
                    case .failure:
                        if !triggerRetry() {
                            seal.fulfill(.notErc721)
                        }
                    }
                }
            }
        }
        let isErc1155Promise = Promise<Bool> { seal in
            withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
                guard let strongSelf = self else { return }
                strongSelf.getIsERC1155ContractCoordinator.getIsERC1155Contract(for: address) { [weak self] result in
                    guard self != nil else { return }
                    switch result {
                    case .success(let isErc1155):
                        seal.fulfill(isErc1155)
                    case .failure:
                        if !triggerRetry() {
                            seal.fulfill(false)
                        }
                    }
                }
            }
        }

        firstly {
            isErc721Promise
        }.done { isErc721 in
            switch isErc721 {
            case .erc721:
                completion(.erc721)
            case .erc721ForTickets:
                completion(.erc721ForTickets)
            case .notErc721:
                break
            }
        }.catch({ e in
            error(value: e, pref: "isErc721Promise", address: address)
        })

        firstly {
            isErc875Promise
        }.done { isErc875 in
            if isErc875 {
                completion(.erc875)
            } else {
                //no-op
            }
        }.catch({ e in
            error(value: e, pref: "isErc875Promise", address: address)
        })

        firstly {
            isErc1155Promise
        }.done { isErc1155 in
            if isErc1155 {
                completion(.erc1155)
            } else {
                //no-op
            }
        }.catch({ e in
            error(value: e, pref: "isErc1155Promise", address: address)
        })

        firstly {
            when(fulfilled: isErc875Promise.asVoid(), isErc721Promise.asVoid(), isErc1155Promise.asVoid())
        }.done { _, _, _ in
            if isErc875Promise.value == false && isErc721Promise.value == .notErc721 && isErc1155Promise.value == false {
                completion(.erc20)
            } else {
                //no-op
            }
        }.catch({ e in
            error(value: e, pref: "isErc20Promise", address: address)
        })
    }
// swiftlint:enable function_body_length
}

