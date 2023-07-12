//
//  Web3.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.09.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt

extension Web3.Utils {
    /*
         guard let wallet = keystore.currentWallet else { fatalError() }
         let message = Data("Hello AlphaWallet".utf8)
         guard let signature = try? keystore.signMessage(message, for: wallet.address, prompt: "Sign Message").get() else { fatalError() }

         switch Web3.Utils.ecrecover(message: message, signature: signature) {
         case .success(let address):
             assert(wallet.address.sameContract(as: address))
         case .failure(let error):
             print(error)
         }
     */

    public static func recoverPublicKey(message: Data, v: UInt8, r: [UInt8], s: [UInt8]) -> Data? {
        Web3.Utils.personalECRecoverPublicKey(message: message, r: r, s: s, v: v)
    }

    public static func ecrecover(message: Data, signature: Data) -> EthereumAddress? {
        //need to hash message here because the web3swift implementation adds prefix
        let messageHash = message.sha3(.keccak256)
        let signatureString = signature.hexString.add0x
        //note: web3swift takes the v value as v - 27, so we need to manually convert this
        let vValue = signatureString.drop0x.substring(from: 128)
        let vInt = Int(vValue, radix: 16)! - 27
        let vString = "0" + String(vInt)
        let signature = "0x" + signatureString.drop0x.substring(to: 128) + vString

        return Web3.Utils.hashECRecover(hash: messageHash, signature: Data(bytes: signature.hexToBytes))
    }

    public static func ecrecover(signedOrder: SignedOrder) -> EthereumAddress? {
        //need to hash message here because the web3swift implementation adds prefix
        let messageHash = Data(bytes: signedOrder.message).sha3(.keccak256)
        //note: web3swift takes the v value as v - 27, so we need to manually convert this
        let vValue = signedOrder.signature.drop0x.substring(from: 128)
        let vInt = Int(vValue, radix: 16)! - 27
        let vString = "0" + String(vInt)
        let signature = "0x" + signedOrder.signature.drop0x.substring(to: 128) + vString

        return Web3.Utils.hashECRecover(hash: messageHash, signature: Data(bytes: signature.hexToBytes))
    }
}
