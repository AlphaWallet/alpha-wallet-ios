// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import BigInt
import Combine

public enum ContractData {
    case name(String)
    case symbol(String)
    case balance(nonFungible: NonFungibleBalance?, fungible: BigUInt?, tokenType: TokenType)
    case decimals(Int)
    case nonFungibleTokenComplete(name: String, symbol: String, balance: NonFungibleBalance, tokenType: TokenType)
    case fungibleTokenComplete(name: String, symbol: String, decimals: Int, value: BigUInt, tokenType: TokenType)
    case delegateTokenComplete
    //TODO: remove failure case and return error instead
    case failed(networkReachable: Bool, error: Error)
}

enum ContractDataPromise {
    case name
    case symbol
    case decimals
    case tokenType
    case erc20Balance
    case erc721ForTicketsBalance
    case erc875Balance
    case erc721Balance
}

enum ContractDataDetectorError: Error {
    case symbolIsEmpty
    case promise(error: Error, ContractDataPromise)
}

public class ContractDataDetector {
    private let contract: AlphaWallet.Address
    private let ercTokenProvider: TokenProviderType
    private let assetDefinitionStore: AssetDefinitionStore
    private let namePromise: Promise<String>
    private let symbolPromise: Promise<String>
    private let tokenTypePromise: Promise<TokenType>
    private let (nonFungibleBalancePromise, nonFungibleBalanceSeal) = Promise<NonFungibleBalance>.pending()
    private let (fungibleBalancePromise, fungibleBalanceSeal) = Promise<BigUInt>.pending()
    private let (decimalsPromise, decimalsSeal) = Promise<Int>.pending()
    private var failed = false
    private let reachability: ReachabilityManagerProtocol
    private let wallet: AlphaWallet.Address
    private let subject = PassthroughSubject<ContractData, Never>()

    private var getErc875TokenBalanceCancellable: AnyCancellable?
    private var getErc721BalanceCancellable: AnyCancellable?
    private var getErc721ForTicketsBalanceCancellable: AnyCancellable?
    private var getErc20BalanceCancellable: AnyCancellable?
    private var getDecimalsCancellable: AnyCancellable?

    public init(contract: AlphaWallet.Address,
                wallet: AlphaWallet.Address,
                ercTokenProvider: TokenProviderType,
                assetDefinitionStore: AssetDefinitionStore,
                analytics: AnalyticsLogger,
                reachability: ReachabilityManagerProtocol) {

        self.reachability = reachability
        self.contract = contract
        self.wallet = wallet
        self.ercTokenProvider = ercTokenProvider
        self.assetDefinitionStore = assetDefinitionStore
        namePromise = Promise { try await ercTokenProvider.getContractName(for: contract) }
        symbolPromise = Promise { try await ercTokenProvider.getContractSymbol(for: contract) }
        tokenTypePromise = Promise { try await ercTokenProvider.getTokenType(for: contract) }
    }

    //Failure to obtain contract data may be due to no-connectivity. So we should check .failed(networkReachable: Bool)
    //Have to use strong self in promises below, otherwise `self` will be destroyed before fetching completes
    public func fetch() -> AnyPublisher<ContractData, Never> {

        assetDefinitionStore.fetchXML(forContract: contract, server: nil)

        firstly {
            tokenTypePromise
        }.done { tokenType in
            self.processTokenType(tokenType)
            self.processName(tokenType: tokenType)
            self.processSymbol(tokenType: tokenType)
        }.catch { error in
            self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .tokenType))
        }

        return subject.eraseToAnyPublisher()
    }

    private func processTokenType(_ tokenType: TokenType) {
        switch tokenType {
        case .erc875:
            getErc875TokenBalanceCancellable = Task {
                do {
                    let balance = try await ercTokenProvider.getErc875TokenBalance(for: wallet, contract: contract)
                    self.nonFungibleBalanceSeal.fulfill(.erc875(balance))
                    self.completionOfPartialData(.balance(nonFungible: .erc875(balance), fungible: nil, tokenType: .erc875))
                } catch {
                    self.nonFungibleBalanceSeal.reject(error)
                    self.decimalsSeal.fulfill(0)
                    self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc875Balance))
                }
            }.asCancellable()
        case .erc721:
            getErc875TokenBalanceCancellable = Task {
                do {
                    let balance = try await ercTokenProvider.getErc721Balance(for: contract)
                    self.nonFungibleBalanceSeal.fulfill(.balance(balance))
                    self.decimalsSeal.fulfill(0)
                    self.completionOfPartialData(.balance(nonFungible: .balance(balance), fungible: nil, tokenType: .erc721))
                } catch {
                    self.nonFungibleBalanceSeal.reject(error)
                    self.decimalsSeal.fulfill(0)
                    self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc721Balance))
                }
            }.asCancellable()
        case .erc721ForTickets:
            getErc875TokenBalanceCancellable = Task {
                do {
                    let balance = try await ercTokenProvider.getErc721ForTicketsBalance(for: contract)

                    self.nonFungibleBalanceSeal.fulfill(.erc721ForTickets(balance))
                    self.decimalsSeal.fulfill(0)
                    self.completionOfPartialData(.balance(nonFungible: .erc721ForTickets(balance), fungible: nil, tokenType: .erc721ForTickets))
                } catch {
                    self.nonFungibleBalanceSeal.reject(error)
                    self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc721ForTicketsBalance))
                }
            }.asCancellable()
        case .erc1155:
            let balance: [String] = .init()
            self.nonFungibleBalanceSeal.fulfill(.balance(balance))
            self.decimalsSeal.fulfill(0)
            self.completionOfPartialData(.balance(nonFungible: .balance(balance), fungible: nil, tokenType: .erc1155))
        case .erc20:
            getErc20BalanceCancellable = Task {
                do {
                    let value = try await ercTokenProvider.getErc20Balance(for: contract)
                    self.fungibleBalanceSeal.fulfill(value)
                    self.completionOfPartialData(.balance(nonFungible: nil, fungible: value, tokenType: .erc20))
                } catch {
                    self.fungibleBalanceSeal.reject(error)
                    self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc20Balance))
                }
            }.asCancellable()

            getDecimalsCancellable = Task {
                do {
                    let decimal = try await ercTokenProvider.getDecimals(for: contract)
                    self.decimalsSeal.fulfill(decimal)
                    self.completionOfPartialData(.decimals(decimal))
                } catch {
                    self.decimalsSeal.reject(error)
                    self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .decimals))
                }
            }.asCancellable()
        case .nativeCryptocurrency:
            break
        }
    }

    private func processName(tokenType: TokenType) {
        firstly {
            namePromise
        }.done { name in
            self.completionOfPartialData(.name(name))
        }.catch { error in
            if tokenType.shouldHaveNameAndSymbol {
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .name))
            } else {
                //We consider name and symbol and empty string because NFTs (ERC721 and ERC1155) don't have to implement `name` and `symbol`. Eg. ENS/721 (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) and Enjin/1155 (0xfaafdc07907ff5120a76b34b731b278c38d6043c)
                //no-op
            }
            self.completionOfPartialData(.name(""))
        }
    }

    private func processSymbol(tokenType: TokenType) {
        firstly {
            symbolPromise
        }.done { symbol in
            self.completionOfPartialData(.symbol(symbol))
        }.catch { error in
            if tokenType.shouldHaveNameAndSymbol {
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .symbol))
            } else {
                //We consider name and symbol and empty string because NFTs (ERC721 and ERC1155) don't have to implement `name` and `symbol`. Eg. ENS/721 (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) and Enjin/1155 (0xfaafdc07907ff5120a76b34b731b278c38d6043c)
                //no-op
            }
            self.completionOfPartialData(.symbol(""))
        }
    }

    private func completionOfPartialData(_ data: ContractData) {
        subject.send(data)
        callCompletionOnAllData()
    }

    private func callCompletionFailed(error: ContractDataDetectorError) {
        guard !failed else { return }
        failed = true
        subject.send(.failed(networkReachable: reachability.isReachable, error: error))
        subject.send(completion: .finished)
    }

    private func callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError) {
        assert(symbolPromise.value != nil && symbolPromise.value?.isEmpty == true)
        //Must check because we also get an empty symbol (and name) if there's no connectivity
        //TODO maybe better to share an instance of the reachability manager
        if reachability.isReachable {
            subject.send(.delegateTokenComplete)
            subject.send(completion: .finished)
        } else {
            callCompletionFailed(error: error)
        }
    }

    private func callCompletionOnAllData() {
        //NOTE: looks like tokenTypePromise always have value, otherwise we can't reach here
        if namePromise.isResolved, symbolPromise.isResolved, let tokenType = tokenTypePromise.value {
            switch tokenType {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                if let nonFungibleBalance = nonFungibleBalancePromise.value {
                    let name = namePromise.value
                    let symbol = symbolPromise.value
                    subject.send(.nonFungibleTokenComplete(name: name ?? "", symbol: symbol ?? "", balance: nonFungibleBalance, tokenType: tokenType))
                    subject.send(completion: .finished)
                }
            case .nativeCryptocurrency, .erc20:
                if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value, let value = fungibleBalancePromise.value {
                    if symbol.isEmpty {
                        callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError.symbolIsEmpty)
                    } else {
                        subject.send(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, value: value, tokenType: tokenType))
                        subject.send(completion: .finished)
                    }
                }
            }
        } else if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value {
            if symbol.isEmpty {
                callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError.symbolIsEmpty)
            } else {
                subject.send(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, value: .zero, tokenType: .erc20))
                subject.send(completion: .finished)
            }
        }
    }
}

public extension TokenType {
    public var shouldHaveNameAndSymbol: Bool {
        switch self {
        case .nativeCryptocurrency, .erc20, .erc875:
            return true
        case .erc721, .erc721ForTickets, .erc1155:
            return false
        }
    }
}
