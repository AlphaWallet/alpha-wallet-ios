// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

protocol CustomUrlSchemeCoordinatorResolver: class {
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

    /// Return true if handled
    //TODO We aren't returning true/false accurately since we use a promise here
    func handleOpen(url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == Eip681Parser.scheme else { return false }
        guard let result = QRCodeValueParser.from(string: url.absoluteString) else { return false }
        switch result {
        case .address:
            break
        case .eip681(let protocolName, let address, let functionName, let params):
            firstly {
                Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse()
            }.done { result in
                guard let (contract: contract, optionalServer, recipient, amount) = result.parameters else { return }
                let server = optionalServer ?? .main
                let tokensDatastore = self.tokensDatastores[server]
                if tokensDatastore.token(forContract: contract) != nil {
                    self.openSendPayFlowFor(server: server, contract: contract, recipient: recipient, amount: amount)
                } else {
                    fetchContractDataFor(address: contract, storage: tokensDatastore, assetDefinitionStore: self.assetDefinitionStore) { data in
                        switch data {
                        case .name, .symbol, .balance, .decimals:
                            break
                        case .nonFungibleTokenComplete:
                            //Not expecting NFT
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
                            tokensDatastore.addCustom(token: token)
                            self.openSendPayFlowFor(server: server, contract: contract, recipient: recipient, amount: amount)
                        case .delegateTokenComplete:
                            break
                        case .failed:
                            break
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
        let transferType = TransferType(token: tokenObject, recipient: recipient, amount: amountConsideringDecimals)
        delegate?.openSendPaymentFlow(.send(type: transferType), server: server, inCoordinator: self)
    }
}
