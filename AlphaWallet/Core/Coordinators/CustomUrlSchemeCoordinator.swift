// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

protocol CustomUrlSchemeCoordinatorDelegate: class {
    func openSendPaymentFlow(_ paymentFlow: PaymentFlow, server: RPCServer, inCoordinator coordinator: CustomUrlSchemeCoordinator)
}

class CustomUrlSchemeCoordinator: Coordinator {
    private let tokensDatastores: ServerDictionary<TokensDataStore>

    var coordinators: [Coordinator] = []
    weak var delegate: CustomUrlSchemeCoordinatorDelegate?

    init(tokensDatastores: ServerDictionary<TokensDataStore>) {
        self.tokensDatastores = tokensDatastores
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == "ethereum" else { return false }

        //TODO extract method and share code with SendViewController. Note that logic is slightly different
        guard let result = QRURLParser.from(string: url.absoluteString) else { return false }

        let server: RPCServer
        if let chainIdStr = result.params["chainId"], let chainId = Int(chainIdStr) {
            server = .init(chainID: chainId)
        } else {
            server = .main
        }
        //if erc20 (eip861 qr code)
        if let recipient = result.params["address"], let amount = result.params["uint256"] {
            guard recipient != "0" && amount != "0" else { return false }
            guard let address = AlphaWallet.Address(string: recipient) else { return false }
            let tokensDatastore = tokensDatastores[server]
            guard let token = tokensDatastore.token(forContract: result.address) else {
                //TODO we ignore EIP861 links that are for ERC20 tokens we don't have in our local database. Fix this by autodetecting the token, making sure it is ERC20 and then using it
                return false
            }

            let transferType: TransferType = .ERC20Token(token, destination: address, amount: amount)
            delegate?.openSendPaymentFlow(.send(type: transferType), server: server, inCoordinator: self)
            return true
        } else {
            //if ether transfer (eip861 qr code)
            let amount: BigInt?
            //Double() import here because BigInt doesn't handle the scientific format, aka. 1.23e12
            if let value = result.params["value"], let amountToSend = Double(value) {
                amount = BigInt(amountToSend)
            } else {
                amount = nil
            }
            let transferType: TransferType = .nativeCryptocurrency(server: server, destination: result.address, amount: amount)
            delegate?.openSendPaymentFlow(.send(type: transferType), server: server, inCoordinator: self)
            return true
        }
    }
}
