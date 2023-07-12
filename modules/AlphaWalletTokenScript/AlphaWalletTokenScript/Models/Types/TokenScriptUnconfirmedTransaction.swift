// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletWeb3
import AlphaWalletCore
import BigInt

public struct TokenScriptUnconfirmedTransaction {
    public let server: RPCServer
    public let value: BigUInt
    public let recipient: AlphaWallet.Address?
    public let contract: AlphaWallet.Address?
    public let data: Data
    public let decodedFunctionCall: DecodedFunctionCall

    public init(server: RPCServer, value: BigUInt, recipient: AlphaWallet.Address?, contract: AlphaWallet.Address?, data: Data = Data(), decodedFunctionCall: DecodedFunctionCall) {
        self.server = server
        self.value = value
        self.recipient = recipient
        self.contract = contract
        self.data = data
        self.decodedFunctionCall = decodedFunctionCall
    }
}
