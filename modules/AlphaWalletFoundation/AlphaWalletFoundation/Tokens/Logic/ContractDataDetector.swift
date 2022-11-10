// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import BigInt

public enum ContractData {
    case name(String)
    case symbol(String)
    case balance(nonFungible: NonFungibleBalance?, fungible: BigInt?, tokenType: TokenType)
    case decimals(Int)
    case nonFungibleTokenComplete(name: String, symbol: String, balance: NonFungibleBalance, tokenType: TokenType)
    case fungibleTokenComplete(name: String, symbol: String, decimals: Int, value: BigInt, tokenType: TokenType)
    case delegateTokenComplete
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
    private let address: AlphaWallet.Address
    private let tokenProvider: TokenProviderType
    private let assetDefinitionStore: AssetDefinitionStore
    private let namePromise: Promise<String>
    private let symbolPromise: Promise<String>
    private let tokenTypePromise: Promise<TokenType>
    private let (nonFungibleBalancePromise, nonFungibleBalanceSeal) = Promise<NonFungibleBalance>.pending()
    private let (fungibleBalancePromise, fungibleBalanceSeal) = Promise<BigInt>.pending()
    private let (decimalsPromise, decimalsSeal) = Promise<Int>.pending()
    private var failed = false
    private var completion: ((ContractData) -> Void)?
    private let reachability: ReachabilityManagerProtocol
    private let wallet: AlphaWallet.Address

    public init(address: AlphaWallet.Address, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, reachability: ReachabilityManagerProtocol) {
        self.reachability = reachability
        self.address = address
        self.wallet = session.account.address
        self.tokenProvider = session.tokenProvider
        self.assetDefinitionStore = assetDefinitionStore
        namePromise = tokenProvider.getContractName(for: address)
        symbolPromise = tokenProvider.getContractSymbol(for: address)
        tokenTypePromise = tokenProvider.getTokenType(for: address)
    }

    //Failure to obtain contract data may be due to no-connectivity. So we should check .failed(networkReachable: Bool)
    //Have to use strong self in promises below, otherwise `self` will be destroyed before fetching completes
    public func fetch(completion: @escaping (ContractData) -> Void) {
        self.completion = completion

        assetDefinitionStore.fetchXML(forContract: address, server: nil)

        firstly {
            tokenTypePromise
        }.done { tokenType in
            self.processTokenType(tokenType)
            self.processName(tokenType: tokenType)
            self.processSymbol(tokenType: tokenType)
        }.catch { error in
            self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .tokenType))
        }
    }

    private func processTokenType(_ tokenType: TokenType) {
        switch tokenType {
        case .erc875:
            tokenProvider.getErc875Balance(for: address).done { balance in
                self.nonFungibleBalanceSeal.fulfill(.erc875(balance))
                self.completionOfPartialData(.balance(nonFungible: .erc875(balance), fungible: nil, tokenType: .erc875))
            }.catch { error in
                self.nonFungibleBalanceSeal.reject(error)
                self.decimalsSeal.fulfill(0)
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc875Balance))
            }
        case .erc721:
            tokenProvider.getErc721Balance(for: address).done { balance in
                self.nonFungibleBalanceSeal.fulfill(.balance(balance))
                self.decimalsSeal.fulfill(0)
                self.completionOfPartialData(.balance(nonFungible: .balance(balance), fungible: nil, tokenType: .erc721))
            }.catch { error in
                self.nonFungibleBalanceSeal.reject(error)
                self.decimalsSeal.fulfill(0)
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc721Balance))
            }
        case .erc721ForTickets:
            tokenProvider.getErc721ForTicketsBalance(for: address).done { balance in
                self.nonFungibleBalanceSeal.fulfill(.erc721ForTickets(balance))
                self.decimalsSeal.fulfill(0)
                self.completionOfPartialData(.balance(nonFungible: .erc721ForTickets(balance), fungible: nil, tokenType: .erc721ForTickets))
            }.catch { error in
                self.nonFungibleBalanceSeal.reject(error)
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc721ForTicketsBalance))
            }
        case .erc1155:
            let balance: [String] = .init()
            self.nonFungibleBalanceSeal.fulfill(.balance(balance))
            self.decimalsSeal.fulfill(0)
            self.completionOfPartialData(.balance(nonFungible: .balance(balance), fungible: nil, tokenType: .erc1155))
        case .erc20:
            tokenProvider.getErc20Balance(for: address).done { value in
                self.fungibleBalanceSeal.fulfill(value)
                self.completionOfPartialData(.balance(nonFungible: nil, fungible: value, tokenType: .erc20))
            }.catch { error in
                self.fungibleBalanceSeal.reject(error)
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .erc20Balance))
            }

            tokenProvider.getDecimals(for: address).done { decimal in
                self.decimalsSeal.fulfill(decimal)
                self.completionOfPartialData(.decimals(decimal))
            }.catch { error in
                self.decimalsSeal.reject(error)
                self.callCompletionFailed(error: ContractDataDetectorError.promise(error: error, .decimals))
            }
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
        completion?(data)
        callCompletionOnAllData()
    }

    private func callCompletionFailed(error: ContractDataDetectorError) {
        guard !failed else { return }
        failed = true

        completion?(.failed(networkReachable: reachability.isReachable, error: error))
    }

    private func callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError) {
        assert(symbolPromise.value != nil && symbolPromise.value?.isEmpty == true)
        //Must check because we also get an empty symbol (and name) if there's no connectivity
        //TODO maybe better to share an instance of the reachability manager
        if reachability.isReachable {
            completion?(.delegateTokenComplete)
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
                    completion?(.nonFungibleTokenComplete(name: name ?? "", symbol: symbol ?? "", balance: nonFungibleBalance, tokenType: tokenType))
                }
            case .nativeCryptocurrency, .erc20:
                if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value, let value = fungibleBalancePromise.value {
                    if symbol.isEmpty {
                        callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError.symbolIsEmpty)
                    } else {
                        completion?(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, value: value, tokenType: tokenType))
                    }
                }
            }
        } else if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value {
            if symbol.isEmpty {
                callCompletionAsDelegateTokenOrNot(error: ContractDataDetectorError.symbolIsEmpty)
            } else {
                completion?(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, value: .zero, tokenType: .erc20))
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
