// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletWeb3

func deriveAddressFromPublicKey(_ key: String) -> AlphaWallet.Address? {
    let recoveredEthereumAddress: EthereumAddress? = Web3.Utils.publicToAddress(Data(hex: key))
    return recoveredEthereumAddress.flatMap { AlphaWallet.Address(address: $0) }
}