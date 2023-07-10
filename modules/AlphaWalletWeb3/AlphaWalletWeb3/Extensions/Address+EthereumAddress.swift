// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress

extension AlphaWallet.Address {
    public init(address: EthereumAddress) {
        self = .ethereumAddress(eip55String: address.address)
    }

    public func sameContract(as contract: EthereumAddress) -> Bool {
        return eip55String == contract.address
    }
}

extension EthereumAddress {
    public init(address: AlphaWallet.Address) {
        //EthereumAddress(Data) is much faster than EthereumAddress(String). This is significant because we can make a few hundred calls
//        let data = Data.fromHex(address.eip55String)!
//        self.init(data)!

        //During testing we found that EthereumAddress(address.eip55String) is faster then self.init(data)!
        //approx time is 0.000980973243713379 while with using self.init(data)! is 2.8967857360839844e-05 seconds.

        self.init(address.eip55String)!
    }
}
