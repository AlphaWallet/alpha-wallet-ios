// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletTrustWalletCoreExtensions
import AlphaWalletWeb3
//TODO reduce dependencies, especially third party ones
import TrustKeystore

fileprivate let emptyPassphrase = ""

public protocol HardwareWallet {
    func signHash(_ hash: Data) async throws -> Data
    func getAddress() async throws -> AlphaWallet.Address
}

extension HDWallet {
    //TODO best to be not public
    public enum functional {}
}

//TODO is there a need for this type? Just pass a set of `String` directly instead?
public enum HardwareWalletSuccessMessages {
    case signatureObtained(String)
    case publicKeyObtained(String)
    case importedSeed(String)

    public var message: String {
        switch self {
        case .signatureObtained(let message):
            return message
        case .publicKeyObtained(let message):
            return message
        case .importedSeed(let message):
            return message
        }
    }
}

//TODO consider move out if this is useful for general wallet, not just hardware wallet. Maybe into Web3.Utils, but those seem like they should be extracted too
//TODO some of these might not fit into `functional`
public extension HDWallet.functional {
    static func convertMnemonicToSeed(_ mnemonic: String) -> Data? {
        let wallet = HDWallet(mnemonic: mnemonic, passphrase: emptyPassphrase)
        return wallet?.seed
    }

    static func deriveAddress0FromMnemonic(_ mnemonic: String) -> AlphaWallet.Address? {
        guard let wallet = HDWallet(mnemonic: mnemonic, passphrase: emptyPassphrase) else { return nil }
        let privateKey: Data = derivePrivateKeyOfAccount0(fromHdWallet: wallet)
        let address = AlphaWallet.Address(fromPrivateKey: privateKey)
        return address
    }

    static func deriveAddressFromPublicKey(_ publicKey: Data) -> AlphaWallet.Address? {
        let recoveredEthereumAddress: EthereumAddress? = Web3.Utils.publicToAddress(publicKey)
        let recoveredAddress: AlphaWallet.Address? = recoveredEthereumAddress.flatMap { AlphaWallet.Address(address: $0) }
        return recoveredAddress
    }

    static func derivePrivateKeyOfAccount0(fromHdWallet wallet: HDWallet) -> Data {
        let firstAccountIndex = UInt32(0)
        let externalChangeConstant = UInt32(0)
        let addressIndex = UInt32(0)
        let privateKey = wallet.getDerivedKey(coin: .ethereum, account: firstAccountIndex, change: externalChangeConstant, address: addressIndex)
        return privateKey.data
    }

    static func hashECRecover(hash: Data, signature: Data) -> AlphaWallet.Address? {
        let recoveredEthereumAddress: EthereumAddress? = Web3.Utils.hashECRecover(hash: hash, signature: signature)
        let recoveredAddress: AlphaWallet.Address? = recoveredEthereumAddress.flatMap { AlphaWallet.Address(address: $0) }
        return recoveredAddress
    }
}
