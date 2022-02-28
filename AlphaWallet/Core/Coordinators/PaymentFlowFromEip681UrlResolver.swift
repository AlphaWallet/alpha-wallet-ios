// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

class PaymentFlowFromEip681UrlResolver: Coordinator {
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let config: Config
    var coordinators: [Coordinator] = []

    init(tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, config: Config) {
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.config = config
    }

    static func canHandleOpen(url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == Eip681Parser.scheme else { return false }
        guard let result = QRCodeValueParser.from(string: url.absoluteString) else { return false }
        switch result {
        case .address:
            return false
        case .eip681:
            return true
        }
    }

    /// Return true if handled
    @discardableResult func resolve(url: URL) -> Promise<(paymentFlow: PaymentFlow, server: RPCServer)>? {
        guard let result = QRCodeValueParser.from(string: url.absoluteString), PaymentFlowFromEip681UrlResolver.canHandleOpen(url: url) else {
            return nil
        }

        let tokensDataStore = self.tokensDataStore
        let assetDefinitionStore = self.assetDefinitionStore
        let config = self.config

        switch result {
        case .address:
            return nil
        case .eip681(let protocolName, let address, let functionName, let params):
            return firstly {
                Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse()
            }.then { result -> Promise<(paymentFlow: PaymentFlow, server: RPCServer)> in
                return Promise<(paymentFlow: PaymentFlow, server: RPCServer)> { seal in
                    guard let (contract: contract, optionalServer, recipient, amount) = result.parameters else {
                        seal.reject(PMKError.cancelled)
                        return
                    }
                    let server = optionalServer ?? config.anyEnabledServer()

                    //NOTE: self is required here because object has delated before resolving state
                    if let token = tokensDataStore.token(forContract: contract, server: server) {
                        let transactionType = Self.transactionType(token, recipient: recipient, amount: amount)

                        seal.fulfill((paymentFlow: .send(type: .transaction(transactionType)), server: server))
                    } else {
                        ContractDataDetector(address: contract, account: tokensDataStore.account, server: server, assetDefinitionStore: assetDefinitionStore).fetch { data in
                            switch data {
                            case .name, .symbol, .balance, .decimals, .nonFungibleTokenComplete, .delegateTokenComplete, .failed:
                                //seal.reject(PMKError.cancelled)
                                break
                            case .fungibleTokenComplete(let name, let symbol, let decimals):
                                //TODO update fetching to retrieve balance too so we can display the correct balance in the view controller
                                //Explicit type declaration to speed up build time. 130msec -> 50ms, as of Xcode 11.7
                                let token: ERCToken = ERCToken(
                                        contract: contract,
                                        server: server,
                                        name: name,
                                        symbol: symbol,
                                        decimals: Int(decimals),
                                        type: .erc20,
                                        balance: ["0"]
                                )
                                let tokenObject = tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: true)[0]

                                let transactionType = Self.transactionType(tokenObject, recipient: recipient, amount: amount)

                                seal.fulfill((paymentFlow: .send(type: .transaction(transactionType)), server: server))
                            }
                        }
                    }
                }
            }
        }
    }

    private static func transactionType(_ tokenObject: TokenObject, recipient: AddressOrEnsName?, amount: String) -> TransactionType {
        let amountConsideringDecimals: String
        if let bigIntAmount = Double(amount).flatMap({ BigInt($0) }) {
            amountConsideringDecimals = EtherNumberFormatter.full.string(from: bigIntAmount, decimals: tokenObject.decimals)
        } else {
            amountConsideringDecimals = ""
        }

        return TransactionType(fungibleToken: tokenObject, recipient: recipient, amount: amountConsideringDecimals)
    }
}
