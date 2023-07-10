// Copyright © 2018 Stormbird PTE. LTD.

import AlphaWalletAddress

///Use an enum as a namespace until Swift has proper namespaces
public typealias AlphaWallet = AlphaWalletAddress.AlphaWallet

extension AlphaWallet.Address {
    public var isLegacy875Contract: Bool {
        let contractString = eip55String
        return Constants.legacy875Addresses.contains { $0.sameContract(as: contractString) }
    }

    public var isLegacy721Contract: Bool {
        return Constants.legacy721Addresses.contains(self)
    }
}
