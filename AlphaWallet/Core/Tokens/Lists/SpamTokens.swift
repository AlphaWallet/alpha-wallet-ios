// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public class SpamTokens {
    //TODO: extract from tokens.json when it's ready
    private let tokens: [AddressAndRPCServer] = [
        AddressAndRPCServer(address: AlphaWallet.Address(string: "0x426ca1ea2406c07d75db9585f22781c096e3d0e0")!, server: .main),
        AddressAndRPCServer(address: AlphaWallet.Address(string: "0x0b91b07beb67333225a5ba0259d55aee10e3a578")!, server: .polygon),
    ]

    public func isSpamToken(_ needle: AddressAndRPCServer) -> Bool {
        tokens.contains(needle)
    }
}
