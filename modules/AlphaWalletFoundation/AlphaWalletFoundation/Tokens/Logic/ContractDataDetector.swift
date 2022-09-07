// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import Alamofire
import PromiseKit

public enum ContractData {
    case name(String)
    case symbol(String)
    case balance(balance: NonFungibleBalance, tokenType: TokenType)
    case decimals(UInt8)
    case nonFungibleTokenComplete(name: String, symbol: String, balance: NonFungibleBalance, tokenType: TokenType)
    case fungibleTokenComplete(name: String, symbol: String, decimals: UInt8)
    case delegateTokenComplete
    case failed(networkReachable: Bool?)
}

public class ContractDataDetector {
    private let address: AlphaWallet.Address
    private let tokenProvider: TokenProviderType
    private let assetDefinitionStore: AssetDefinitionStore
    private let namePromise: Promise<String>
    private let symbolPromise: Promise<String>
    private let tokenTypePromise: Promise<TokenType>
    private let (nonFungibleBalancePromise, nonFungibleBalanceSeal) = Promise<NonFungibleBalance>.pending()
    private let (decimalsPromise, decimalsSeal) = Promise<UInt8>.pending()
    private var failed = false
    private var completion: ((ContractData) -> Void)?

    public init(address: AlphaWallet.Address, account: Wallet, server: RPCServer, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger) {
        self.address = address
        self.tokenProvider = TokenProvider(account: account, server: server, analytics: analytics)
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
            namePromise
        }.done { name in
            self.completionOfPartialData(.name(name))
        }.catch { _ in
            self.callCompletionFailed()
            //We consider name and symbol and empty string because NFTs (ERC721 and ERC1155) don't have to implement `name` and `symbol`. Eg. ENS/721 (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) and Enjin/1155 (0xfaafdc07907ff5120a76b34b731b278c38d6043c)
            self.completionOfPartialData(.name(""))
        }

        firstly {
            symbolPromise
        }.done { symbol in
            self.completionOfPartialData(.symbol(symbol))
        }.catch { _ in
            self.callCompletionFailed()
            //We consider name and symbol and empty string because NFTs (ERC721 and ERC1155) don't have to implement `name` and `symbol`. Eg. ENS/721 (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) and Enjin/1155 (0xfaafdc07907ff5120a76b34b731b278c38d6043c)
            self.completionOfPartialData(.symbol(""))
        }

        firstly {
            tokenTypePromise
        }.done { tokenType in
            switch tokenType {
            case .erc875:
                self.tokenProvider.getERC875Balance(for: self.address).done { balance in
                    self.nonFungibleBalanceSeal.fulfill(.erc875(balance))
                    self.completionOfPartialData(.balance(balance: .erc875(balance), tokenType: .erc875))
                }.catch { error in
                    self.nonFungibleBalanceSeal.reject(error)
                    self.decimalsSeal.fulfill(0)
                    self.callCompletionFailed()
                }
            case .erc721:
                self.tokenProvider.getERC721Balance(for: self.address).done { balance in
                    self.nonFungibleBalanceSeal.fulfill(.balance(balance))
                    self.decimalsSeal.fulfill(0)
                    self.completionOfPartialData(.balance(balance: .balance(balance), tokenType: .erc721))
                }.catch { error in
                    self.nonFungibleBalanceSeal.reject(error)
                    self.decimalsSeal.fulfill(0)
                    self.callCompletionFailed()
                }
            case .erc721ForTickets:
                self.tokenProvider.getERC721ForTicketsBalance(for: self.address).done { balance in
                    self.nonFungibleBalanceSeal.fulfill(.erc721ForTickets(balance))
                    self.decimalsSeal.fulfill(0)
                    self.completionOfPartialData(.balance(balance: .erc721ForTickets(balance), tokenType: .erc721ForTickets))
                }.catch { error in
                    self.nonFungibleBalanceSeal.reject(error)
                    self.callCompletionFailed()
                }
            case .erc1155:
                let balance: [String] = .init()
                self.nonFungibleBalanceSeal.fulfill(.balance(balance))
                self.decimalsSeal.fulfill(0)
                self.completionOfPartialData(.balance(balance: .balance(balance), tokenType: .erc1155))
            case .erc20:
                self.tokenProvider.getDecimals(for: self.address).done { decimal in
                    self.decimalsSeal.fulfill(decimal)
                    self.completionOfPartialData(.decimals(decimal))
                }.catch { error in
                    self.decimalsSeal.reject(error)
                    self.callCompletionFailed()
                }
            case .nativeCryptocurrency:
                break
            }
        }.cauterize()
    }

    private func completionOfPartialData(_ data: ContractData) {
        completion?(data)
        callCompletionOnAllData()
    }

    private func callCompletionFailed() {
        guard !failed else {
            return
        }
        failed = true
        //TODO maybe better to share an instance of the reachability manager
        completion?(.failed(networkReachable: NetworkReachabilityManager()?.isReachable))
    }

    private func callCompletionAsDelegateTokenOrNot() {
        assert(symbolPromise.value != nil && symbolPromise.value?.isEmpty == true)
        //Must check because we also get an empty symbol (and name) if there's no connectivity
        //TODO maybe better to share an instance of the reachability manager
        if let reachabilityManager = NetworkReachabilityManager(), reachabilityManager.isReachable {
            completion?(.delegateTokenComplete)
        } else {
            callCompletionFailed()
        }
    }

    private func callCompletionOnAllData() {
        if namePromise.isResolved, symbolPromise.isResolved, let tokenType = tokenTypePromise.value {
            switch tokenType {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                if let nonFungibleBalance = nonFungibleBalancePromise.value {
                    let name = namePromise.value
                    let symbol = symbolPromise.value
                    completion?(.nonFungibleTokenComplete(name: name ?? "", symbol: symbol ?? "", balance: nonFungibleBalance, tokenType: tokenType))
                }
            case .nativeCryptocurrency, .erc20:
                if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value {
                    if symbol.isEmpty {
                        callCompletionAsDelegateTokenOrNot()
                    } else {
                        completion?(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals))
                    }
                }
            }
        } else if let name = namePromise.value, let symbol = symbolPromise.value, let decimals = decimalsPromise.value {
            if symbol.isEmpty {
                callCompletionAsDelegateTokenOrNot()
            } else {
                completion?(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals))
            }
        }
    }
}
