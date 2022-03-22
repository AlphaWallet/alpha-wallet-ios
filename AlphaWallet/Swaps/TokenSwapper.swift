// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import SwiftyJSON

struct TokenToSwap {
    let address: AlphaWallet.Address
    let server: RPCServer
    let symbol: String
    let decimals: Int
}

//hhh remove after development
struct Mainnet {
    static let maticToken = AlphaWallet.Address(string: "0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0")!
    static let usdtToken = AlphaWallet.Address(string: "0xdAC17F958D2ee523a2206206994597C13D831ec7")!
}
struct Matic {
    static let wethToken = AlphaWallet.Address(string: "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619")!
    static let usdcToken = AlphaWallet.Address(string: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174")!
}

enum SwapError: Error {
    case unableToBuildSwapUnsignedTransactionFromSwapProvider
    case userCancelledApproval
    case approveTransactionNotCompleted
    case unknownError
}

class TokenSwapper {
    struct Url {
        static let fetchQuote = URL(string: "https://li.quest/v1/quote")!
        static let fetchAvailableTokenConnections = URL(string: "https://li.quest/v1/connections")!
        static let fetchSupportedChains = URL(string: "https://li.quest/v1/chains")!
    }

    private var supportedServers: [RPCServer] = []
    private var supportedTokens: [RPCServer: SwapPairs] = [:]

    func start() {
        fetchSupportedChains()
    }

    @discardableResult private func fetchSupportedChains() -> Promise<[RPCServer]> {
        guard supportedServers.isEmpty else { return .value(supportedServers) }
        return firstly {
            TokenSwapper.functional.fetchSupportedChains()
        }.recover { error -> Promise<[RPCServer]> in
            NSLog("xxx error: \(error)")
            throw error
        }.get { servers in
            self.supportedServers = servers
            NSLog("xxx chains: \(servers)")
        }
    }

    func fetchSupportedTokens(forServer server: RPCServer) -> Promise<SwapPairs> {
        if let supportedTokens = supportedTokens[server] {
            return .value(supportedTokens)
        } else {
            return firstly {
                fetchSupportedChains()
            }.then { _ -> Promise<SwapPairs> in
                if self.supportedServers.contains(server) {
                    return TokenSwapper.functional.fetchSupportedTokens(forServer: server)
                } else {
                    struct NotSupportedChain: Error {}
                    throw NotSupportedChain()
                }
            }.get { swapPair in
                self.supportedTokens[server] = swapPair
            }
        }
    }

    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, fromAmount: BigUInt) -> Promise<SwapQuote> {
        functional.fetchSwapQuote(fromToken: fromToken, toToken: toToken, wallet: wallet, fromAmount: fromAmount)
    }

    func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionConfirmationConfiguration) {
        functional.buildSwapTransaction(keystore: keystore, unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
    }
}

extension TokenSwapper {
    enum functional {
    }
}

fileprivate extension TokenSwapper.functional {
    static func fetchSupportedChains() -> Promise<[RPCServer]> {
        //hhh remove after development
        //return Promise.value([.polygon])

        NSLog("xxx fetchSupportedChains()…")
        return firstly {
            Alamofire.request(TokenSwapper.Url.fetchSupportedChains).validate().responseJSON()
        }.map { rawJson, _ -> [RPCServer] in
            let json = JSON(rawJson)
            let chains = json["chains"].arrayValue
            return chains.compactMap { each in
                let chainId = each["id"].intValue
                return RPCServer(chainIdOptional: chainId)
            }
        }
    }

    static func fetchSupportedTokens(forServer server: RPCServer) -> Promise<SwapPairs> {
        //hhh remove? Or keep for development, faster?
        //if case RPCServer.polygon = server {
        //    return Promise<[AlphaWallet.Address]>.value([Matic.usdcToken])
        //}

        let parameters: [String: Any] = [
            "fromChain": server.chainID,
            "toChain": server.chainID,
        ]
        NSLog("xxx fetchSupportedTokens()…")
        return firstly {
            Alamofire.request(TokenSwapper.Url.fetchAvailableTokenConnections, method: .post, parameters: parameters).validate().responseData()
        }.map { jsonData, _ -> SwapPairs in
            //hhh remove
            //print(rawJson)

            if let connections: Swap.Connections = try? JSONDecoder().decode(Swap.Connections.self, from: jsonData) {
                return SwapPairs(connections: connections)
            } else {
                return SwapPairs(connections: .init(connections: []))
            }
        }
    }

    static func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, fromAmount: BigUInt) -> Promise<SwapQuote> {
        let parameters: [String: Any] = [
            "fromChain": fromToken.server.chainID,
            "toChain": toToken.server.chainID,
            "fromToken": fromToken.address.eip55String,
            "toToken": toToken.address.eip55String,
            "fromAddress": wallet.eip55String,
            "fromAmount": String(fromAmount),
            "order": "BEST_VALUE",
            "slippage": "0.05",
            //hhh remove both
            //"allowExchanges": "paraswap,openocean,0x,uniswap,sushiswap,quickswap,honeyswap,pancakeswap,spookyswap,viperswap,solarbeam,dodo",
            //"allowExchanges": "paraswap",
        ]
        NSLog("xxx buildUnsignedSwapTransaction()…")
        //NSLog("xxx with url: \(Alamofire.request(TokenSwapper.fetchQuoteUrl, parameters: parameters).debugDescription)")
        //hhh remove
        print("xxx with url: \(Alamofire.request(TokenSwapper.Url.fetchQuote, parameters: parameters).debugDescription))")
        return firstly {
            Alamofire.request(TokenSwapper.Url.fetchQuote, parameters: parameters).responseJSON()
        }.map { rawJson, _ -> SwapQuote in
            NSLog("xxx swap generated: \(rawJson)")
            if let jsonData: Data = try? JSONSerialization.data(withJSONObject: rawJson), let swapQuote = try? JSONDecoder().decode(SwapQuote.self, from: jsonData) {
                //hhh remove
                //print(rawJson)

                NSLog("xxx jsonData: \(jsonData)")
                NSLog("xxx swap is: \(swapQuote.unsignedSwapTransaction)")
                NSLog("xxx swap has gasLimit: \(swapQuote.unsignedSwapTransaction.gasLimit)")
                return swapQuote
            } else {
                NSLog("xxx no json for building unsigned swap transaction")
                throw SwapError.unableToBuildSwapUnsignedTransactionFromSwapProvider
            }
        }
    }

    static func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionConfirmationConfiguration) {
        let configuration: TransactionConfirmationConfiguration = .swapTransaction(keystore: keystore, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount )
        let transactionType: TransactionType = .prebuilt(unsignedTransaction.server)
        let transaction: UnconfirmedTransaction = .init(transactionType: transactionType, value: unsignedTransaction.value, recipient: unsignedTransaction.from, contract: unsignedTransaction.to, data: unsignedTransaction.data, gasLimit: unsignedTransaction.gasLimit, gasPrice: unsignedTransaction.gasPrice)
        return (transaction, configuration)
    }
}