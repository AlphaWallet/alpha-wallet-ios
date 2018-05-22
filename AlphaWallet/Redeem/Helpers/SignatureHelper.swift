//
//  SignatureHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/8/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import TrustKeystore
import BigInt

class SignatureHelper {

    class func signatureAsHex(for message: String, account: Account) -> String? {
        let keystore = try! EtherKeystore()
        let signature = keystore.signMessageData(message.data(using: String.Encoding.utf8), for: account)
        let signatureHex = try? signature.dematerialize().hex(options: .upperCase)
        guard let data = signatureHex else {
            return nil
        }
        return data
    }

    class func signatureAsDecimal(for message: String, account: Account) -> String? {
        let signatureHex = signatureAsHex(for: message, account: account)!
        return BigInt(signatureHex, radix: 16)!.description
    }
}
