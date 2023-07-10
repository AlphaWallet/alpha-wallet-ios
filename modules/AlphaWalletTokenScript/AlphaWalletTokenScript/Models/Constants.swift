// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress
import AlphaWalletCore
import BigInt

public struct Constants {
    public static let nullAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!
    public static let nativeCryptoAddressInDatabase = nullAddress

    public static let nullTokenIdBigUInt = BigUInt(0)

    static let ensContractOnMainnet = AlphaWallet.Address.ethereumAddress(eip55String: "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85")

    //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
    static let katContractAddress = "0x06012c8cf97bead5deae237070f9587f8e7a266d"
    public static let katNameFallback = "AlphaWallet.katNameFallback"

    // FIFA hardcoded FIFA token address
    public static let ticketContractAddress = AlphaWallet.Address(string: "0xA66A3F08068174e8F005112A8b2c7A507a822335")!
    static let ticketContractAddressRopsten = AlphaWallet.Address(string: "0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3")!

    // UEFA hardcoded addresses
    public static let uefaMainnet = (AlphaWallet.Address(string: "0x89D142Bef8605646881C68dcD48cDAF17FE597dC")!, RPCServer.main)
    static let gnoGnosis = (AlphaWallet.Address(string: "0x9c58bacc331c9aa871afd802db6379a98e80cedb")!, RPCServer.xDai)

    enum TokenScript {
        static let urlSchemeForResources = "tokenscript-resource:///"
        static let validatorAPI = "https://aw.app/api/v1/verifyXMLDSig"
    }
}
