// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

protocol CustomUrlSchemeCoordinatorResolver: AnyObject {
    func openSendPaymentFlow(_ paymentFlow: PaymentFlow, server: RPCServer, inCoordinator coordinator: CustomUrlSchemeCoordinator)
}

class CustomUrlSchemeCoordinator: Coordinator {
    private let tokensDatastores: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore

    var coordinators: [Coordinator] = []
    weak var delegate: CustomUrlSchemeCoordinatorResolver?

    init(tokensDatastores: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore) {
        self.tokensDatastores = tokensDatastores
        self.assetDefinitionStore = assetDefinitionStore
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
    func handleOpen(url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == Eip681Parser.scheme else { return false }
        guard let result = QRCodeValueParser.from(string: url.absoluteString) else { return false }
        switch result {
        case .address:
            return false
        case .eip681(let protocolName, let address, let functionName, let params):
            firstly {
                Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse()
            }.done { result in
                guard let (contract: contract, optionalServer, recipient, amount) = result.parameters else {
                    return
                }
                let server = optionalServer ?? .main
                //NOTE: self is required here because object has delated before resolving state
                let tokensDatastore = self.tokensDatastores[server]
                if tokensDatastore.token(forContract: contract) != nil {
                    self.openSendPayFlowFor(server: server, contract: contract, recipient: recipient, amount: amount)
                } else {
                    ContractDataDetector(address: contract, account: tokensDatastore.account, server: tokensDatastore.server, assetDefinitionStore: self.assetDefinitionStore).fetch { data in
                        switch data {
                        case .name, .symbol, .balance, .decimals, .nonFungibleTokenComplete, .delegateTokenComplete, .failed:
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
                            tokensDatastore.addCustom(token: token, shouldUpdateBalance: true)
                            self.openSendPayFlowFor(server: server, contract: contract, recipient: recipient, amount: amount)
                        }
                    }
                }
            }.cauterize()
        }

        return true
    }

    private func openSendPayFlowFor(server: RPCServer, contract: AlphaWallet.Address, recipient: AddressOrEnsName?, amount: String) {
        let tokensDatastore = tokensDatastores[server]
        guard let tokenObject = tokensDatastore.token(forContract: contract) else { return }
        let amountConsideringDecimals: String
        if let bigIntAmount = Double(amount).flatMap({ BigInt($0) }) {
            amountConsideringDecimals = EtherNumberFormatter.full.string(from: bigIntAmount, decimals: tokenObject.decimals)
        } else {
            amountConsideringDecimals = ""
        }
        let transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: amountConsideringDecimals)
        delegate?.openSendPaymentFlow(.send(type: .transaction(transactionType)), server: server, inCoordinator: self)
    }
}
