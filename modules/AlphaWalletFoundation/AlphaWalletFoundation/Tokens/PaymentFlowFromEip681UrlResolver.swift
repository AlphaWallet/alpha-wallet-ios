// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

public final class PaymentFlowFromEip681UrlResolver {
    private let tokensService: TokenProvidable & TokenAddable
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let config: Config
    private let account: Wallet

    public init(tokensService: TokenProvidable & TokenAddable, account: Wallet, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, config: Config) {
        self.tokensService = tokensService
        self.account = account
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.config = config
    }

    public static func canHandleOpen(url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == Eip681Parser.scheme else { return false }
        switch QRCodeValueParser.from(string: url.absoluteString) {
        case .address, .none:
            return false
        case .eip681:
            return true
        }
    }

    /// Return true if handled
    @discardableResult public func resolve(url: URL) -> Promise<(paymentFlow: PaymentFlow, server: RPCServer)>? {
        guard let result = QRCodeValueParser.from(string: url.absoluteString), PaymentFlowFromEip681UrlResolver.canHandleOpen(url: url) else {
            return nil
        }

        switch result {
        case .address:
            return nil
        case .eip681(let protocolName, let address, let functionName, let params):
            return firstly {
                Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse()
            }.then { [account, config, analytics, assetDefinitionStore, tokensService] result -> Promise<(paymentFlow: PaymentFlow, server: RPCServer)> in
                return Promise<(paymentFlow: PaymentFlow, server: RPCServer)> { seal in
                    guard let (contract: contract, optionalServer, recipient, amount) = result.parameters else {
                        seal.reject(PMKError.cancelled)
                        return
                    }
                    let server = optionalServer ?? config.anyEnabledServer()

                    //NOTE: self is required here because object has delated before resolving state
                    if let token = tokensService.token(for: contract, server: server) {
                        let transactionType = PaymentFlowFromEip681UrlResolver.transactionType(token, recipient: recipient, amount: amount)

                        seal.fulfill((paymentFlow: .send(type: .transaction(transactionType)), server: server))
                    } else {
                        ContractDataDetector(address: contract, account: account, server: server, assetDefinitionStore: assetDefinitionStore, analytics: analytics).fetch { data in
                            switch data {
                            case .name, .symbol, .balance, .decimals, .nonFungibleTokenComplete, .delegateTokenComplete, .failed:
                                break
                            case .fungibleTokenComplete(let name, let symbol, let decimals):
                                //TODO update fetching to retrieve balance too so we can display the correct balance in the view controller
                                //Explicit type declaration to speed up build time. 130msec -> 50ms, as of Xcode 11.7
                                let ercToken: ERCToken = ERCToken(
                                        contract: contract,
                                        server: server,
                                        name: name,
                                        symbol: symbol,
                                        decimals: Int(decimals),
                                        type: .erc20,
                                        balance: .balance(["0"]))
                                let token = tokensService.addCustom(tokens: [ercToken], shouldUpdateBalance: true)[0]
                                let transactionType = PaymentFlowFromEip681UrlResolver.transactionType(token, recipient: recipient, amount: amount)

                                seal.fulfill((paymentFlow: .send(type: .transaction(transactionType)), server: server))
                            }
                        }
                    }
                }
            }
        }
    }

    private static func transactionType(_ token: Token, recipient: AddressOrEnsName?, amount: String) -> TransactionType {
        let amountConsideringDecimals: String
        if let bigIntAmount = Double(amount).flatMap({ BigInt($0) }) {
            amountConsideringDecimals = EtherNumberFormatter.full.string(from: bigIntAmount, decimals: token.decimals)
        } else {
            amountConsideringDecimals = ""
        }

        return TransactionType(fungibleToken: token, recipient: recipient, amount: amountConsideringDecimals)
    }
}
